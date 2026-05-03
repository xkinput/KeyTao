// rime_tui.cc — Interactive Rime schema TUI with live memory monitoring
// Build:  see scripts/build_rime_tui.sh  (or auto-built by nix develop shellHook)
// Usage:  rime_tui --user-data-dir DIR [--shared-data-dir DIR] [--schema SCHEMA_ID]
//
// Keys:
//   printable chars  → feed to Rime
//   Backspace        → delete last stroke
//   Space            → confirm first candidate
//   1-9              → pick candidate N
//   ← →              → page candidates
//   Tab              → cycle schemas
//   Alt+1~8          → toggle schema switch 1-8 (needs Option=Meta in terminal)
//   `1~`8            → toggle schema switch 1-8 (universal, no config needed)
//   ESC              → clear composition
//   Ctrl+C           → quit (q is passed to Rime normally)

#include <atomic>
#include <mutex>
#include <string>
#include <thread>
#include <vector>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <unistd.h>
#if defined(__APPLE__)
#include <mach/mach.h>
#endif
#include <ncurses.h>
#include <rime_api.h>
#include <csignal>
#include <ctime>

// ── X11 keysyms used by Rime (no X11 header needed) ─────────────────────────
static constexpr int RK_BackSpace = 0xFF08;
static constexpr int RK_Return = 0xFF0D;
static constexpr int RK_Escape = 0xFF1B;
static constexpr int RK_Left = 0xFF51;
static constexpr int RK_Up = 0xFF52;
static constexpr int RK_Right = 0xFF53;
static constexpr int RK_Down = 0xFF54;
static constexpr int RK_Page_Up = 0xFF55;
static constexpr int RK_Page_Down = 0xFF56;

// ── Platform RSS (KB) ────────────────────────────────────────────────────────
static long rss_kb()
{
#if defined(__APPLE__)
  mach_task_basic_info_data_t info;
  mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
  if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO,
                (task_info_t)&info, &count) == KERN_SUCCESS)
    return (long)(info.resident_size / 1024);
  return 0;
#else
  FILE *f = fopen("/proc/self/status", "r");
  if (!f)
    return 0;
  char buf[256];
  long vm = 0;
  while (fgets(buf, sizeof(buf), f))
    if (sscanf(buf, "VmRSS: %ld kB", &vm) == 1)
      break;
  fclose(f);
  return vm;
#endif
}

// ── Shared state (mem thread → main thread) ──────────────────────────────────
struct MemState
{
  long rss = 0;
  long peak = 0;
  long baseline = 0;
  long history[60] = {}; // ring buffer, one sample per second (KB)
  int tick = 0;          // total samples taken
  std::mutex mtx;
};

static MemState g_mem;
static std::atomic<bool> g_running{true};
static std::atomic<bool> g_mem_updated{false};

static void mem_thread_fn()
{
  while (g_running)
  {
    long cur = rss_kb();
    {
      std::lock_guard<std::mutex> lk(g_mem.mtx);
      g_mem.rss = cur;
      if (cur > g_mem.peak)
        g_mem.peak = cur;
      g_mem.history[g_mem.tick % 60] = cur;
      g_mem.tick++;
    }
    g_mem_updated = true;
    sleep(1);
  }
}

// ── App state ────────────────────────────────────────────────────────────────
static RimeSessionId g_session = 0;
static std::string g_committed;
static std::vector<std::string> g_schema_ids;
static std::vector<std::string> g_schema_names;
static int g_schema_idx = 0;
static std::string g_status_msg;
static bool g_switch_prefix = false;   // true after ` is pressed: next digit 1-8 toggles a switch
static bool g_baseline_locked = false; // reset baseline after first real keystroke

// Tracks one continuous typing session (reset after 10s idle)
struct InputSession
{
  long rss_start = 0;     // RSS (KB) when this typing session began
  long rss_at_commit = 0; // RSS (KB) at last commit
  long rss_post_sync = 0; // RSS sampled 1s after commit
  int keystrokes = 0;
  int commits = 0;
  bool synced = false;
};
static InputSession g_input_sess;

// Cross-session leak trend tracker
struct LeakTracker
{
  long rss_at_warmup = 0; // RSS after first commit (post-warmup baseline)
  int total_commits = 0;
  long total_growth = 0; // total RSS growth (KB) since warmup
  bool warmed_up = false;
};
static LeakTracker g_leak;

// ── Rime notification state ──────────────────────────────────────────────────
struct NotifyState
{
  std::string type;  // "deploy", "schema", "option"
  std::string value; // e.g. "success", "keytao", "!simplification"
  time_t ts = 0;
  std::mutex mtx;
};
static NotifyState g_notify;
static std::atomic<time_t> g_last_activity{0}; // epoch of last keystroke

// ── Signal handling ──────────────────────────────────────────────────────────
static volatile sig_atomic_t g_quit = 0;
static void handle_sigint(int) { g_quit = 1; }

struct SwitchInfo
{
  std::string option;              // e.g. "simplification"
  std::vector<std::string> states; // e.g. ["简体","繁體"]
};
static std::vector<SwitchInfo> g_switches;

static void load_switches(const std::string &schema_id)
{
  g_switches.clear();
  RimeApi *rime = rime_get_api();
  RimeConfig cfg;
  std::string cfg_id = schema_id + ".schema";
  if (!rime->schema_open(schema_id.c_str(), &cfg))
    return;

  RimeConfigIterator it;
  if (!rime->config_begin_list(&it, &cfg, "switches"))
  {
    rime->config_close(&cfg);
    return;
  }
  while (rime->config_next(&it))
  {
    SwitchInfo sw;
    char path[256];
    snprintf(path, sizeof(path), "%s/name", it.path);
    const char *name = rime->config_get_cstring(&cfg, path);
    if (!name)
      continue;
    sw.option = name;

    RimeConfigIterator sit;
    snprintf(path, sizeof(path), "%s/states", it.path);
    if (rime->config_begin_list(&sit, &cfg, path))
    {
      while (rime->config_next(&sit))
      {
        const char *sv = rime->config_get_cstring(&cfg, sit.path);
        sw.states.push_back(sv ? sv : "");
      }
      rime->config_end(&sit);
    }
    g_switches.push_back(sw);
  }
  rime->config_end(&it);
  rime->config_close(&cfg);
}

static void on_message(void *, RimeSessionId, const char *msg_type, const char *msg_value)
{
  std::lock_guard<std::mutex> lk(g_notify.mtx);
  g_notify.type = msg_type ? msg_type : "";
  g_notify.value = msg_value ? msg_value : "";
  g_notify.ts = time(nullptr);
}

// Classify what librime is currently doing; flag suspicious idle memory growth.
// growth_10s_kb: RSS delta over last 10s. idle_secs: seconds since last keystroke.
static void classify_rime_activity(long rss_kb_cur, long growth_10s_kb, long idle_secs,
                                   std::string &tag, bool &suspicious)
{
  suspicious = false;
  std::string ntype, nval;
  time_t nts;
  {
    std::lock_guard<std::mutex> lk(g_notify.mtx);
    ntype = g_notify.type;
    nval = g_notify.value;
    nts = g_notify.ts;
  }
  int since = (int)(time(nullptr) - nts);

  // librime lifecycle notifications
  if (ntype == "deploy" && nval == "start")
  {
    tag = "[Deploy] building index...";
    return;
  }
  if (ntype == "deploy" && since < 5)
  {
    tag = "[Deploy] " + nval;
    return;
  }
  if (ntype == "schema" && since < 15)
  {
    tag = "[Dict] loading prism/table";
    return;
  }

  RimeApi *rime = rime_get_api();
  bool opencc = rime && g_session && rime->get_option(g_session, "simplification");
  bool lua_hint = rime && g_session &&
                  (rime->get_option(g_session, "topup_hint") ||
                   rime->get_option(g_session, "sbb_hint"));

  // ── actively typing ──────────────────────────────────────────────────────
  if (idle_secs < 3 && g_input_sess.keystrokes > 0)
  {
    long sess_growth = rss_kb_cur - g_input_sess.rss_start;
    char buf[128];
    if (g_leak.warmed_up && g_leak.total_commits > 0)
    {
      long avg_kb = g_leak.total_growth / g_leak.total_commits;
      snprintf(buf, sizeof(buf), "[Typing] +%ldKB this sess | avg +%ldKB/commit (%d commits)",
               sess_growth > 0 ? sess_growth : 0L, avg_kb, g_leak.total_commits);
    }
    else if (!g_leak.warmed_up)
      snprintf(buf, sizeof(buf), "[Typing] +%ldKB (warmup: dict+Lua loading)",
               sess_growth > 0 ? sess_growth : 0L);
    else
      snprintf(buf, sizeof(buf), "[Typing] +%ldKB this sess",
               sess_growth > 0 ? sess_growth : 0L);
    tag = buf;
    return;
  }

  // ── just committed ───────────────────────────────────────────────────────
  if (g_input_sess.synced)
  {
    char buf[128];
    if (g_leak.warmed_up && g_leak.total_commits > 0)
    {
      long avg_kb = g_leak.total_growth / g_leak.total_commits;
      const char *verdict = (avg_kb < 32) ? "no leak" : (avg_kb < 128) ? "normal"
                                                                       : "check Lua";
      snprintf(buf, sizeof(buf), "[Committed] avg +%ldKB/commit (%d) — %s",
               avg_kb, g_leak.total_commits, verdict);
    }
    else
      snprintf(buf, sizeof(buf), "[Committed] warmup done, continue typing to measure");
    tag = buf;
    return;
  }

  // ── idle, flat growth — retained heap is expected behavior ───────────────
  if (idle_secs >= 3 && growth_10s_kb <= 256)
  {
    std::string flags;
    if (opencc)
      flags += "OpenCC ";
    if (lua_hint)
      flags += "Lua ";
    if (g_leak.warmed_up && g_leak.total_commits > 0)
    {
      long avg_kb = g_leak.total_growth / g_leak.total_commits;
      const char *verdict = (avg_kb < 32) ? "no leak" : (avg_kb < 128) ? "normal"
                                                                       : "check Lua";
      char buf[128];
      snprintf(buf, sizeof(buf), "[Idle] avg +%ldKB/commit (%d) — %s%s",
               avg_kb, g_leak.total_commits, verdict,
               flags.empty() ? "" : (" | " + flags.substr(0, flags.size() - 1)).c_str());
      tag = buf;
    }
    else
      tag = "[Idle]" + (flags.empty() ? "" : " " + flags.substr(0, flags.size() - 1));
    return;
  }

  // ── idle but still growing fast → suspicious ─────────────────────────────
  if (growth_10s_kb > 1024 && idle_secs >= 5)
  {
    suspicious = true;
    if (opencc)
    {
      tag = "\u26a0 [OpenCC] model growing (idle)";
      return;
    }
    if (lua_hint)
    {
      tag = "\u26a0 [Lua] GC not freeing? filter leak?";
      return;
    }
    tag = "\u26a0 [Dict] unexpected idle growth";
    return;
  }

  // moderate growth while not actively typing → one-time loads
  if (growth_10s_kb > 256)
  {
    if (opencc)
    {
      tag = "[OpenCC] loading model";
      return;
    }
    if (lua_hint)
    {
      tag = "[Lua] filter VM growing";
      return;
    }
    tag = "[Dict] prism/table loading";
    return;
  }

  std::string flags;
  if (opencc)
    flags += "OpenCC ";
  if (lua_hint)
    flags += "Lua ";
  tag = "[Idle]" + (flags.empty() ? "" : " " + flags.substr(0, flags.size() - 1));
}

// flush all pending commits into g_committed
static void collect_commits()
{
  RimeApi *rime = rime_get_api();
  RIME_STRUCT(RimeCommit, commit);
  bool got_commit = false;
  while (rime->get_commit(g_session, &commit))
  {
    if (commit.text)
      g_committed += commit.text;
    rime->free_commit(&commit);
    got_commit = true;
  }
  if (got_commit)
  {
    long rss_now = rss_kb();
    g_input_sess.rss_at_commit = rss_now;
    g_input_sess.synced = true;
    g_input_sess.commits++;

    // Update cross-session leak tracker
    if (!g_leak.warmed_up)
    {
      // First commit: dict/Lua/OpenCC are now loaded — use this as leak baseline
      g_leak.rss_at_warmup = rss_now;
      g_leak.warmed_up = true;
    }
    else
    {
      long growth = rss_now - g_leak.rss_at_warmup - g_leak.total_growth;
      if (growth > 0)
        g_leak.total_growth += growth;
      g_leak.total_commits++;
    }
  }
}

static void switch_schema(int idx)
{
  RimeApi *rime = rime_get_api();
  g_schema_idx = idx;
  rime->select_schema(g_session, g_schema_ids[idx].c_str());
  rime->clear_composition(g_session);
  collect_commits();   // discard preedit, don't add to g_committed
  g_committed.clear(); // fresh slate per schema

  load_switches(g_schema_ids[idx]);

  long cur = rss_kb();
  {
    std::lock_guard<std::mutex> lk(g_mem.mtx);
    g_mem.baseline = cur;
    if (cur > g_mem.peak)
      g_mem.peak = cur;
  }
  g_status_msg = "Switched \u2192 " + g_schema_names[idx];
}

// ── TUI drawing ──────────────────────────────────────────────────────────────
static void draw(WINDOW *win)
{
  int rows, cols;
  getmaxyx(win, rows, cols);
  werase(win);

  // row 0: title bar
  wattron(win, A_BOLD | A_REVERSE);
  mvwprintw(win, 0, 0, " Rime TUI%-*s", cols - 9, "");
  wattroff(win, A_BOLD | A_REVERSE);

  // row 1: schema switcher
  std::string sch = " Schema:";
  for (int i = 0; i < (int)g_schema_names.size(); ++i)
  {
    if (i == g_schema_idx)
    {
      sch += " [" + g_schema_names[i] + "]";
    }
    else
    {
      sch += "  " + g_schema_names[i];
    }
  }
  sch += "  (Tab)";
  mvwprintw(win, 1, 0, "%-*s", cols, sch.substr(0, cols).c_str());

  // row 2: memory stats + librime activity classification
  long rss, peak, baseline, growth_10s;
  {
    std::lock_guard<std::mutex> lk(g_mem.mtx);
    rss = g_mem.rss;
    peak = g_mem.peak;
    baseline = g_mem.baseline;
    int t = g_mem.tick;
    long old = (t >= 10) ? g_mem.history[(t - 10) % 60] : g_mem.history[0];
    growth_10s = (t >= 10) ? (rss - old) : 0;
    // sample post-sync RSS on next tick after sync
    if (g_input_sess.synced && g_input_sess.rss_post_sync == 0)
      g_input_sess.rss_post_sync = rss;
  }
  long delta = rss - baseline;
  long idle_secs = (g_last_activity.load() == 0)
                       ? 999
                       : (long)(time(nullptr) - g_last_activity.load());
  // reset input session after 10s idle and post-sync has been sampled
  if (idle_secs >= 10 && g_input_sess.rss_post_sync > 0)
  {
    g_input_sess = InputSession{}; // clear for next session
  }
  std::string activity_tag;
  bool mem_suspicious = false;
  classify_rime_activity(rss, growth_10s, idle_secs, activity_tag, mem_suspicious);

  char mem_buf[256];
  snprintf(mem_buf, sizeof(mem_buf),
           " RSS: %.1f MB  \u0394%+.1f MB  Peak: %.1f MB  %s",
           rss / 1024.0, delta / 1024.0, peak / 1024.0, activity_tag.c_str());
  if (mem_suspicious)
    wattron(win, COLOR_PAIR(4) | A_BOLD);
  else
    wattron(win, COLOR_PAIR(1));
  mvwprintw(win, 2, 0, "%-*s", cols, mem_buf);
  if (mem_suspicious)
    wattroff(win, COLOR_PAIR(4) | A_BOLD);
  else
    wattroff(win, COLOR_PAIR(1));

  // separator
  mvwhline(win, 3, 0, ACS_HLINE, cols);

  // row 4: switches (Alt+1~8 or `1~`8 to toggle)
  RimeApi *rime = rime_get_api();
  {
    int x = 5; // after " Sw:"
    mvwprintw(win, 4, 0, " Sw:");
    for (int i = 0; i < (int)g_switches.size() && i < 8; ++i)
    {
      bool on = rime->get_option(g_session, g_switches[i].option.c_str());
      const std::string &label = (g_switches[i].states.size() > (size_t)(on ? 1 : 0))
                                     ? g_switches[i].states[on ? 1 : 0]
                                     : g_switches[i].option;
      char token[64];
      snprintf(token, sizeof(token), g_switch_prefix ? " [%d]%s" : " M%d:%s", i + 1, label.c_str());
      if (x + (int)strlen(token) >= cols)
        break;
      if (on)
      {
        wattron(win, COLOR_PAIR(3) | A_BOLD);
        mvwprintw(win, 4, x, "%s", token);
        wattroff(win, COLOR_PAIR(3) | A_BOLD);
      }
      else
      {
        wattron(win, A_DIM);
        mvwprintw(win, 4, x, "%s", token);
        wattroff(win, A_DIM);
      }
      x += (int)strlen(token);
    }
    if (g_switches.empty())
      mvwprintw(win, 4, 5, "(none)");
  }

  // separator
  mvwhline(win, 5, 0, ACS_HLINE, cols);

  // rows 6-7: preedit + candidates
  RIME_STRUCT(RimeContext, ctx);
  bool has_ctx = rime->get_context(g_session, &ctx);
  if (has_ctx && ctx.composition.length > 0)
  {
    const char *pre = ctx.composition.preedit ? ctx.composition.preedit : "";
    mvwprintw(win, 6, 0, " Preedit:  %s", pre);

    std::string cands = " Cands:   ";
    for (int i = 0; i < ctx.menu.num_candidates && i < 9; ++i)
    {
      const char *text = ctx.menu.candidates[i].text ? ctx.menu.candidates[i].text : "";
      const char *comment = ctx.menu.candidates[i].comment ? ctx.menu.candidates[i].comment : "";
      char buf[128];
      if (comment[0])
        snprintf(buf, sizeof(buf), " %d.%s%s", i + 1, text, comment);
      else
        snprintf(buf, sizeof(buf), " %d.%s", i + 1, text);
      cands += buf;
    }
    if (ctx.menu.num_candidates > 0 &&
        (ctx.menu.page_no > 0 || !ctx.menu.is_last_page))
      cands += "  \u2190\u2192";
    mvwprintw(win, 7, 0, "%-*s", cols, cands.substr(0, (size_t)cols).c_str());
  }
  else
  {
    mvwprintw(win, 6, 0, " Preedit:  (empty)");
    mvwprintw(win, 7, 0, " Cands:    \u2014");
  }
  if (has_ctx)
    rime->free_context(&ctx);

  // separator
  mvwhline(win, 8, 0, ACS_HLINE, cols);

  // rows 9+: committed text
  mvwprintw(win, 9, 0, " Committed:");
  int text_cols = cols - 2;
  int commit_rows = rows - 12;
  if (commit_rows < 2)
    commit_rows = 2;

  // show tail that fits
  std::string disp = g_committed;
  size_t max_chars = (size_t)(text_cols * commit_rows);
  if (disp.size() > max_chars)
    disp = disp.substr(disp.size() - max_chars);
  for (int r = 0; r < commit_rows; ++r)
  {
    if (disp.empty())
      break;
    std::string line = disp.substr(0, (size_t)text_cols);
    disp = disp.size() > (size_t)text_cols ? disp.substr((size_t)text_cols) : "";
    mvwprintw(win, 10 + r, 1, "%s", line.c_str());
  }

  // bottom separator + status/help
  if (rows > 2)
  {
    mvwhline(win, rows - 2, 0, ACS_HLINE, cols);
    std::string help = " ESC=clear  Tab=schema  `N or Alt+N=switch(1-8)  1-9=pick  Space=confirm  \u2190\u2192=page  Ctrl+C=quit";
    if (!g_status_msg.empty())
      help = " " + g_status_msg;
    wattron(win, A_DIM);
    mvwprintw(win, rows - 1, 0, "%-*s", cols, help.substr(0, (size_t)cols).c_str());
    wattroff(win, A_DIM);
  }

  wrefresh(win);
}

// ── Main ─────────────────────────────────────────────────────────────────────
int main(int argc, char *argv[])
{
  const char *user_data_dir = nullptr;
  const char *shared_data_dir = nullptr;
  const char *init_schema = nullptr;

  for (int i = 1; i < argc; ++i)
  {
    if (!strcmp(argv[i], "--user-data-dir") && i + 1 < argc)
      user_data_dir = argv[++i];
    else if (!strcmp(argv[i], "--shared-data-dir") && i + 1 < argc)
      shared_data_dir = argv[++i];
    else if (!strcmp(argv[i], "--schema") && i + 1 < argc)
      init_schema = argv[++i];
  }

  if (!user_data_dir)
  {
    fprintf(stderr,
            "Usage: rime_tui --user-data-dir DIR\n"
            "                [--shared-data-dir DIR]\n"
            "                [--schema SCHEMA_ID]\n");
    return 1;
  }

  // fall back to: RIME_SHARED env → nix store → /usr/share/rime-data
  std::string shared_str;
  if (!shared_data_dir)
  {
    const char *env = getenv("RIME_SHARED");
    if (env && *env)
    {
      shared_str = env;
    }
    else
    {
      // probe nix store (same logic as measure_memory.sh)
      FILE *fp = popen(
          "ls -d /nix/store/*/share/rime-data 2>/dev/null"
          " | grep -v keytao | sort -V | tail -1",
          "r");
      if (fp)
      {
        char buf[512] = {};
        if (fgets(buf, sizeof(buf), fp))
        {
          size_t n = strlen(buf);
          while (n > 0 && (buf[n - 1] == '\n' || buf[n - 1] == '\r'))
            buf[--n] = '\0';
          shared_str = buf;
        }
        pclose(fp);
      }
      if (shared_str.empty())
        shared_str = "/usr/share/rime-data";
    }
    shared_data_dir = shared_str.c_str();
  }

  // ── Deploy & init Rime ────────────────────────────────────────────────────
  RimeApi *rime = rime_get_api();
  RIME_STRUCT(RimeTraits, traits);
  traits.app_name = "rime.tui";
  traits.user_data_dir = user_data_dir;
  traits.shared_data_dir = shared_data_dir;
  traits.distribution_name = "rime_tui";
  traits.distribution_code_name = "rime_tui";
  traits.distribution_version = "0.1.0";
  traits.log_dir = "/tmp";

  signal(SIGINT, handle_sigint);
  rime->setup(&traits);
  rime->set_notification_handler(&on_message, nullptr);
  rime->initialize(nullptr);

  fprintf(stderr, "Deploying %s ...\n", user_data_dir);
  if (rime->start_maintenance(/*full_check=*/True))
    rime->join_maintenance_thread();
  fprintf(stderr, "Ready.\n");

  // seed memory baseline after deploy
  {
    std::lock_guard<std::mutex> lk(g_mem.mtx);
    g_mem.baseline = rss_kb();
    g_mem.rss = g_mem.baseline;
    g_mem.peak = g_mem.baseline;
  }

  g_session = rime->create_session();
  if (!g_session)
  {
    fprintf(stderr, "ERROR: cannot create Rime session\n");
    rime->finalize();
    return 1;
  }

  // collect schema list
  RimeSchemaList slist;
  if (rime->get_schema_list(&slist))
  {
    for (size_t i = 0; i < slist.size; ++i)
    {
      g_schema_ids.push_back(slist.list[i].schema_id);
      g_schema_names.push_back(slist.list[i].name);
    }
    rime->free_schema_list(&slist);
  }
  if (g_schema_ids.empty())
  {
    fprintf(stderr, "ERROR: no schemas found in %s\n", user_data_dir);
    rime->destroy_session(g_session);
    rime->finalize();
    return 1;
  }

  // pick initial schema
  g_schema_idx = 0;
  if (init_schema)
  {
    for (int i = 0; i < (int)g_schema_ids.size(); ++i)
    {
      if (g_schema_ids[i] == init_schema)
      {
        g_schema_idx = i;
        break;
      }
    }
  }
  rime->select_schema(g_session, g_schema_ids[g_schema_idx].c_str());
  load_switches(g_schema_ids[g_schema_idx]);

  // ── Start memory polling thread ───────────────────────────────────────────
  std::thread mem_thr(mem_thread_fn);

  // ── ncurses init ──────────────────────────────────────────────────────────
  setlocale(LC_ALL, "");
  WINDOW *win = initscr();
  cbreak();
  noecho();
  keypad(win, TRUE);
  nodelay(win, TRUE);
  curs_set(0);
  set_escdelay(50);
  if (has_colors())
  {
    start_color();
    use_default_colors();
    init_pair(1, COLOR_GREEN, -1);  // memory line
    init_pair(2, COLOR_CYAN, -1);   // schema active
    init_pair(3, COLOR_YELLOW, -1); // switch active / status
    init_pair(4, COLOR_RED, -1);    // memory leak warning
  }

  draw(win);

  // ── Event loop ────────────────────────────────────────────────────────────
  while (true)
  {
    int ch = wgetch(win);

    if (g_quit)
      break;

    if (ch == ERR)
    {
      if (g_mem_updated.exchange(false))
      {
        // if synced but post-sync RSS not yet captured, sample it now
        if (g_input_sess.synced && g_input_sess.rss_post_sync == 0)
        {
          std::lock_guard<std::mutex> lk(g_mem.mtx);
          g_input_sess.rss_post_sync = g_mem.rss;
        }
        g_status_msg.clear();
        draw(win);
      }
      usleep(20000);
      continue;
    }

    if (ch == KEY_RESIZE)
    {
      draw(win);
      continue;
    }

    g_last_activity.store(time(nullptr));
    // start or continue an input session
    if (g_input_sess.keystrokes == 0)
    {
      g_input_sess.rss_start = rss_kb();
      g_input_sess.rss_post_sync = 0;
      g_input_sess.commits = 0;
      g_input_sess.synced = false;
    }
    g_input_sess.keystrokes++;
    g_status_msg.clear();
    bool need_draw = true;

    if (ch == 27)
    {
      // peek next char to distinguish bare ESC from Alt+digit (ESC + '1'..'8')
      int next = wgetch(win);
      if (next >= '1' && next <= '8')
      {
        int sw_idx = next - '1';
        if (sw_idx < (int)g_switches.size())
        {
          bool cur = rime->get_option(g_session, g_switches[sw_idx].option.c_str());
          rime->set_option(g_session, g_switches[sw_idx].option.c_str(), !cur);
          const std::string &lbl = (!cur && g_switches[sw_idx].states.size() > 1)
                                       ? g_switches[sw_idx].states[1]
                                       : (g_switches[sw_idx].states.size() > 0
                                              ? g_switches[sw_idx].states[0]
                                              : g_switches[sw_idx].option);
          g_status_msg = "Alt+" + std::to_string(sw_idx + 1) + ": " +
                         g_switches[sw_idx].option + " \u2192 " + lbl;
        }
        else
        {
          need_draw = false;
        }
      }
      else
      {
        // bare ESC: clear composition; push back unrelated char
        if (next != ERR)
          ungetch(next);
        rime->clear_composition(g_session);
        collect_commits();
      }
    }
    else if (ch == KEY_BACKSPACE || ch == 127 || ch == '\b')
    {
      rime->process_key(g_session, RK_BackSpace, 0);
    }
    else if (ch == '\n' || ch == '\r' || ch == KEY_ENTER)
    {
      rime->process_key(g_session, RK_Return, 0);
    }
    else if (ch == ' ')
    {
      rime->process_key(g_session, ' ', 0);
    }
    else if (ch == KEY_LEFT)
    {
      rime->process_key(g_session, RK_Left, 0);
    }
    else if (ch == KEY_RIGHT)
    {
      rime->process_key(g_session, RK_Right, 0);
    }
    else if (ch == KEY_UP)
    {
      rime->process_key(g_session, RK_Up, 0);
    }
    else if (ch == KEY_DOWN)
    {
      rime->process_key(g_session, RK_Down, 0);
    }
    else if (ch == KEY_PPAGE)
    {
      rime->process_key(g_session, RK_Page_Up, 0);
    }
    else if (ch == KEY_NPAGE)
    {
      rime->process_key(g_session, RK_Page_Down, 0);
    }
    else if (ch == '\t')
    {
      switch_schema((g_schema_idx + 1) % (int)g_schema_ids.size());
    }
    else if (ch >= '1' && ch <= '9')
    {
      if (g_switch_prefix)
      {
        // ` + digit: toggle switch
        g_switch_prefix = false;
        int sw_idx = ch - '1';
        if (sw_idx < (int)g_switches.size())
        {
          bool cur = rime->get_option(g_session, g_switches[sw_idx].option.c_str());
          rime->set_option(g_session, g_switches[sw_idx].option.c_str(), !cur);
          const std::string &lbl = (!cur && g_switches[sw_idx].states.size() > 1)
                                       ? g_switches[sw_idx].states[1]
                                       : (g_switches[sw_idx].states.size() > 0
                                              ? g_switches[sw_idx].states[0]
                                              : g_switches[sw_idx].option);
          g_status_msg = "`" + std::to_string(sw_idx + 1) + ": " +
                         g_switches[sw_idx].option + " \u2192 " + lbl;
        }
        else
        {
          need_draw = false;
        }
      }
      else
      {
        rime->process_key(g_session, ch, 0);
      }
    }
    else if (ch == '`')
    {
      g_switch_prefix = !g_switch_prefix;
      if (g_switch_prefix)
        g_status_msg = "Switch mode: press 1-8 to toggle, or ` to cancel";
    }
    else if (ch >= 1 && ch <= 8)
    {
      // swallow stray Ctrl+A..H to avoid accidental triggers
      need_draw = false;
    }
    else if (ch >= 32 && ch < 127)
    {
      if (!g_baseline_locked)
      {
        g_baseline_locked = true;
        std::lock_guard<std::mutex> lk(g_mem.mtx);
        g_mem.baseline = g_mem.rss;
      }
      rime->process_key(g_session, ch, 0);
    }
    else
    {
      need_draw = false;
    }

    if (need_draw)
    {
      collect_commits();
      draw(win);
    }
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────
  g_running = false;
  mem_thr.join();
  endwin();

  rime->destroy_session(g_session);
  rime->finalize();
  return 0;
}

// mem_bench.cc — Rime schema memory benchmark
// Build: c++ -std=c++17 -O2 -I$LIBRIME_INCLUDE mem_bench.cc -L$LIBRIME_LIB -lrime -o mem_bench
// Usage: mem_bench --user-data-dir DIR --shared-data-dir DIR --schema SCHEMA_ID [--strokes N]
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#include <algorithm>
#include <unistd.h>
#include <sys/resource.h>
#if defined(__APPLE__)
#include <mach/mach.h>
#endif
#include <rime_api.h>

// ── platform current RSS (KB) ─────────────────────────────────────────────
// NOTE: returns *current* resident set, not peak high-water mark.
//   macOS: mach_task_basic_info.resident_size (can decrease after free/eviction)
//   Linux: /proc/self/status VmRSS (same semantics)
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

// ── helpers ──────────────────────────────────────────────────────────────────
static RimeSessionId g_session = 0;

static void on_message(void *, RimeSessionId, const char *type, const char *val)
{
  // suppress all deploy messages to keep output clean
  (void)type;
  (void)val;
}

static void flush_commit(RimeSessionId sid)
{
  RimeApi *rime = rime_get_api();
  RIME_STRUCT(RimeCommit, commit);
  while (rime->get_commit(sid, &commit))
  {
    rime->free_commit(&commit);
  }
}

static int simulate(RimeSessionId sid, const char *keys)
{
  return rime_get_api()->simulate_key_sequence(sid, keys);
}

// ── main ─────────────────────────────────────────────────────────────────────
int main(int argc, char *argv[])
{
  const char *user_data_dir = nullptr;
  const char *shared_data_dir = nullptr;
  const char *schema_id = nullptr;
  int strokes = 300;
  std::vector<int> checkpoints;
  // leak-test mode
  int rounds = 0;
  int per_round = 1000;
  int rest_sec = 20;

  for (int i = 1; i < argc; ++i)
  {
    if (!strcmp(argv[i], "--user-data-dir") && i + 1 < argc)
      user_data_dir = argv[++i];
    else if (!strcmp(argv[i], "--shared-data-dir") && i + 1 < argc)
      shared_data_dir = argv[++i];
    else if (!strcmp(argv[i], "--schema") && i + 1 < argc)
      schema_id = argv[++i];
    else if (!strcmp(argv[i], "--strokes") && i + 1 < argc)
      strokes = atoi(argv[++i]);
    else if (!strcmp(argv[i], "--checkpoints") && i + 1 < argc)
    {
      char *buf = strdup(argv[++i]);
      for (char *tok = strtok(buf, ","); tok; tok = strtok(nullptr, ","))
        checkpoints.push_back(atoi(tok));
      free(buf);
    }
    else if (!strcmp(argv[i], "--rounds") && i + 1 < argc)
      rounds = atoi(argv[++i]);
    else if (!strcmp(argv[i], "--per-round") && i + 1 < argc)
      per_round = atoi(argv[++i]);
    else if (!strcmp(argv[i], "--rest-sec") && i + 1 < argc)
      rest_sec = atoi(argv[++i]);
  }

  if (!user_data_dir || !shared_data_dir || !schema_id)
  {
    fprintf(stderr,
            "Usage: mem_bench --user-data-dir DIR --shared-data-dir DIR\n"
            "                 --schema SCHEMA_ID [--strokes N]\n"
            "                 [--checkpoints N1,N2,N3]\n"
            "                 [--rounds N --per-round N --rest-sec N]\n");
    return 1;
  }

  // if --checkpoints given, run until the last checkpoint; otherwise use --strokes
  if (!checkpoints.empty())
  {
    std::sort(checkpoints.begin(), checkpoints.end());
    strokes = checkpoints.back();
  }
  else
  {
    checkpoints.push_back(strokes);
  }

  RimeApi *rime = rime_get_api();
  RIME_STRUCT(RimeTraits, traits);
  traits.app_name = "rime.mem_bench";
  traits.user_data_dir = user_data_dir;
  traits.shared_data_dir = shared_data_dir;
  traits.distribution_name = "mem_bench";
  traits.distribution_code_name = "mem_bench";
  traits.distribution_version = "0.0.1";

  rime->setup(&traits);
  rime->set_notification_handler(&on_message, nullptr);

  // ── init & deploy ────────────────────────────────────────────────────────
  rime->initialize(nullptr);
  if (rime->start_maintenance(/*full_check=*/False))
  {
    rime->join_maintenance_thread();
  }

  long rss_after_init = rss_kb();

  RimeSessionId sid = rime->create_session();
  if (!sid)
  {
    fprintf(stderr, "ERROR: cannot create session (deploy failed?)\n");
    return 1;
  }

  // ── select schema ────────────────────────────────────────────────────────
  if (!rime->select_schema(sid, schema_id))
  {
    fprintf(stderr, "ERROR: cannot select schema '%s'\n", schema_id);
    fprintf(stderr, "       (schema not in schema_list?)\n");
    // print available schemas for debugging
    RimeSchemaList list;
    if (rime->get_schema_list(&list))
    {
      fprintf(stderr, "Available schemas:\n");
      for (size_t i = 0; i < list.size; ++i)
        fprintf(stderr, "  [%s] %s\n", list.list[i].schema_id, list.list[i].name);
      rime->free_schema_list(&list);
    }
    rime->destroy_session(sid);
    rime->finalize();
    return 1;
  }
  flush_commit(sid);
  long rss_after_schema = rss_kb();

  // ── leak-test mode: N rounds of M strokes, sleep between each ────────────
  if (rounds > 0)
  {
    static const char *const inputs[] = {
        "vf",
        "va",
        "vb",
        "vc",
        "vd",
        "ve",
        "vg",
        "vh",
        "vi",
        "vj",
        "vk",
        "vl",
        "vm",
        "vn",
        "vo",
        "vp",
        "vq",
        "vr",
        "vs",
        "vt",
        "vu",
        "vw",
        "vx",
        "vy",
        "aa",
        "ab",
        "ac",
        "ad",
        "ae",
        "af",
        "ba",
        "bb",
        "bc",
        "bd",
        "be",
        "bf",
        "ca",
        "cb",
        "cc",
        "cd",
        "ce",
        "cf",
        "da",
        "db",
        "dc",
        "ea",
        "eb",
        "ec",
        "fa",
        "fb",
        "fc",
        "ga",
        "gb",
        "ha",
    };
    static const int n_inputs = sizeof(inputs) / sizeof(inputs[0]);

    printf("schema=%s\n", schema_id);
    printf("rss_after_schema=%ld\n", rss_after_schema);
    fflush(stdout);

    int total = 0;
    for (int r = 1; r <= rounds; ++r)
    {
      long round_peak = rss_kb();
      for (int i = 0; i < per_round; ++i)
      {
        simulate(sid, inputs[total % n_inputs]);
        long rss = rss_kb();
        if (rss > round_peak)
          round_peak = rss;
        simulate(sid, "Return");
        flush_commit(sid);
        ++total;
      }
      printf("round_%d_strokes=%d\n", r, total);
      printf("round_%d_peak=%ld\n", r, round_peak);
      fflush(stdout);

      sleep(rest_sec);

      printf("round_%d_rest=%ld\n", r, rss_kb());
      fflush(stdout);
    }

    rime->destroy_session(sid);
    rime->finalize();
    return 0;
  }

  // ── simulate keystrokes ──────────────────────────────────────────────────
  // KeyTao uses consonant+vowel combos. Drive typical 2-4 key sequences.
  static const char *const inputs[] = {
      "vf",
      "va",
      "vb",
      "vc",
      "vd",
      "ve",
      "vg",
      "vh",
      "vi",
      "vj",
      "vk",
      "vl",
      "vm",
      "vn",
      "vo",
      "vp",
      "vq",
      "vr",
      "vs",
      "vt",
      "vu",
      "vw",
      "vx",
      "vy",
      "aa",
      "ab",
      "ac",
      "ad",
      "ae",
      "af",
      "ba",
      "bb",
      "bc",
      "bd",
      "be",
      "bf",
      "ca",
      "cb",
      "cc",
      "cd",
      "ce",
      "cf",
      "da",
      "db",
      "dc",
      "ea",
      "eb",
      "ec",
      "fa",
      "fb",
      "fc",
      "ga",
      "gb",
      "ha",
  };
  static const int n_inputs = sizeof(inputs) / sizeof(inputs[0]);

  // checkpoint index pointer
  int cp_idx = 0;
  int n_cp = (int)checkpoints.size();
  std::vector<long> rss_at_cp(n_cp, 0); // peak RSS up to each checkpoint

  long rss_peak = rss_after_schema;
  for (int i = 0; i < strokes; ++i)
  {
    simulate(sid, inputs[i % n_inputs]);
    long r = rss_kb();
    if (r > rss_peak)
      rss_peak = r;
    simulate(sid, "Return");
    flush_commit(sid);

    int done = i + 1;
    while (cp_idx < n_cp && done >= checkpoints[cp_idx])
    {
      rss_at_cp[cp_idx] = rss_peak; // peak up to this point
      cp_idx++;
    }
  }

  // ── idle: clear composition, measure immediately ─────────────────────────
  rime->clear_composition(sid);
  flush_commit(sid);
  long rss_idle = rss_kb();

  // ── rest: sleep 5s, let OS reclaim mmap pages, then remeasure ────────────
  sleep(5);
  long rss_after_rest = rss_kb();

  // ── report ───────────────────────────────────────────────────────────────
  printf("schema=%s\n", schema_id);
  printf("rss_after_init=%ld\n", rss_after_init);
  printf("rss_after_schema=%ld\n", rss_after_schema);
  for (int j = 0; j < n_cp; ++j)
    printf("rss_at_%d=%ld\n", checkpoints[j], rss_at_cp[j]);
  printf("rss_idle=%ld\n", rss_idle);
  printf("rss_after_rest=%ld\n", rss_after_rest);

  rime->destroy_session(sid);
  rime->finalize();
  return 0;
}

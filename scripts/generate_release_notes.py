#!/usr/bin/env python3
"""Generate concise KeyTao release notes from git history since the previous v* tag."""

from __future__ import annotations

import re
import subprocess
import sys
from collections import Counter

DICT_LABELS = {
    "rime/keytao.single.dict.yaml": "单字",
    "rime/keytao.phrase.dict.yaml": "词组",
    "rime/keytao.supplement.dict.yaml": "补充词库",
    "rime/keytao.symbol.dict.yaml": "符号",
    "rime/keytao.link.dict.yaml": "链接",
    "rime/keytao.english.dict.yaml": "英文",
    "rime/keytao.css.dict.yaml": "词组（CSS）",
    "rime/keytao.css-single.dict.yaml": "单字（CSS）",
    "rime/keytao-cx.dict.yaml": "次选",
}

SEMVER_RE = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$")
CO_AUTHOR_RE = re.compile(r"^Co-authored-by:\s*(.+?)\s*<([^>]+)>\s*$", re.IGNORECASE)
BOT_NAME_RE = re.compile(r"\[bot\]$|^keytao-bot$|^github-actions$|^dependabot", re.IGNORECASE)
AUTO_SYNC_SUBJECT_RE = re.compile(r"^Update dictionaries\b", re.IGNORECASE)


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], text=True, errors="replace")


def find_previous_tag(current_version: str) -> str | None:
    tags = [t.strip() for t in git("tag", "-l", "v*", "--sort=-v:refname").splitlines() if t.strip()]
    semver_tags = [t for t in tags if SEMVER_RE.match(t) and t != current_version]
    if not semver_tags:
        return None
    if SEMVER_RE.match(current_version):
        cur_tuple = tuple(int(x) for x in SEMVER_RE.match(current_version).groups())
        older = [t for t in semver_tags if tuple(int(x) for x in SEMVER_RE.match(t).groups()) < cur_tuple]
        if older:
            return older[0]
    return semver_tags[0]


def parse_dict_stats(rev_range: str) -> tuple[int, list[tuple[str, int, int, int]]]:
    diff_text = git("diff", "--unified=0", rev_range, "--", "rime/*.dict.yaml")
    added_by_file: dict[str, Counter[str]] = {}
    removed_by_file: dict[str, Counter[str]] = {}
    current_file: str | None = None

    for line in diff_text.splitlines():
        if line.startswith("+++ b/"):
            current_file = line[6:].strip()
            continue
        if line.startswith("--- ") or line.startswith("@@") or not current_file:
            continue
        if current_file not in DICT_LABELS:
            continue
        if not line.startswith(("+", "-")):
            continue
        body = line[1:]
        if "\t" not in body or body.lstrip().startswith("#"):
            continue
        word = body.split("\t", 1)[0].strip()
        if word:
            target = added_by_file if line[0] == "+" else removed_by_file
            target.setdefault(current_file, Counter())[word] += 1

    total_entries = 0
    stats: list[tuple[str, int, int, int]] = []
    for path, label in DICT_LABELS.items():
        added = added_by_file.get(path, Counter())
        removed = removed_by_file.get(path, Counter())
        changed = sum((added & removed).values())
        created = sum((added - removed).values())
        deleted = sum((removed - added).values())
        file_total = created + changed + deleted
        if file_total > 0:
            total_entries += file_total
            stats.append((label, created, changed, deleted))

    return total_entries, stats


def parse_commits_and_contributors(rev_range: str) -> tuple[list[str], list[str]]:
    raw = git("log", rev_range, "--format=%an%x1f%s%x1f%b%x1e")
    other_commits: list[str] = []
    contributors: list[str] = []
    seen_lower: set[str] = set()

    def add_contributor(name: str) -> None:
        cleaned = name.strip()
        if not cleaned or BOT_NAME_RE.search(cleaned):
            return
        # Skip AI co-author trailers in public contributor credits
        if cleaned.lower().startswith(("claude", "copilot", "cursor", "gemini")):
            return
        key = cleaned.lower()
        if key not in seen_lower:
            seen_lower.add(key)
            contributors.append(cleaned)

    for record in raw.split("\x1e"):
        record = record.strip("\n")
        if not record:
            continue
        parts = record.split("\x1f", 2)
        if len(parts) < 2:
            continue
        author = parts[0].strip()
        subject = parts[1].strip()
        body = parts[2] if len(parts) > 2 else ""

        add_contributor(author)
        for body_line in body.splitlines():
            match = CO_AUTHOR_RE.match(body_line.strip())
            if match:
                add_contributor(match.group(1))

        if subject and not AUTO_SYNC_SUBJECT_RE.match(subject):
            other_commits.append(subject)

    return other_commits, contributors


def generate_notes(version: str) -> str:
    prev_tag = find_previous_tag(version)
    rev_range = f"{prev_tag}..HEAD" if prev_tag else "HEAD~1..HEAD"

    total_entries, stats = parse_dict_stats(rev_range)
    other_commits, contributors = parse_commits_and_contributors(rev_range)

    lines: list[str] = []

    if total_entries > 0:
        lines.append("### 更新统计")
        lines.append("")
        lines.append(f"- 总计：**{total_entries}** 条词条")
        for label, created, changed, deleted in stats:
            parts = []
            if created:
                parts.append(f"新增 {created}")
            if changed:
                parts.append(f"修改 {changed}")
            if deleted:
                parts.append(f"删除 {deleted}")
            lines.append(f"- **{label}**：{'，'.join(parts)}")
        lines.append("")

    if other_commits:
        lines.append("### 其他更新" if total_entries > 0 else "### 更新内容")
        lines.append("")
        for subject in other_commits:
            lines.append(f"- {subject}")
        lines.append("")

    if contributors:
        lines.append(f"### 参与贡献（{len(contributors)} 位）")
        lines.append("")
        lines.append("、".join(contributors))
        lines.append("")

    if not lines:
        lines.append(f"KeyTao {version} 方案更新。")

    return "\n".join(lines).rstrip() + "\n"


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: generate_release_notes.py <version>", file=sys.stderr)
        sys.exit(1)
    print(generate_notes(sys.argv[1]), end="")


if __name__ == "__main__":
    main()

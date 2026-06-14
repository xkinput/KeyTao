#!/usr/bin/env python3
import argparse
import sys
from pathlib import Path


DEFAULT_EXTENDED_DICT = "rime/keytao.extended.dict.yaml"
SEARCH_DIRS = ("rime", "extend-dicts")


def parse_args():
    parser = argparse.ArgumentParser(
        description="Merge dictionaries referenced by keytao.extended into code<TAB>text lines."
    )
    parser.add_argument(
        "-e",
        "--extended",
        default=DEFAULT_EXTENDED_DICT,
        help=f"extended dictionary file to read (default: {DEFAULT_EXTENDED_DICT})",
    )
    parser.add_argument(
        "-o",
        "--output",
        help="output file; writes to stdout when omitted",
    )
    parser.add_argument(
        "--include-duplicates",
        action="store_true",
        help="keep duplicate code/text pairs instead of removing later repeats",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="fail when a referenced dictionary cannot be found",
    )
    return parser.parse_args()


def repo_root():
    return Path(__file__).resolve().parents[1]


def read_lines(path):
    return path.read_text(encoding="utf-8-sig").splitlines()


def strip_inline_comment(value):
    return value.split("#", 1)[0].strip()


def parse_import_tables(path):
    tables = []
    in_import_tables = False

    for line in read_lines(path):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        if not in_import_tables:
            if stripped == "import_tables:":
                in_import_tables = True
            continue

        if not line.startswith((" ", "\t", "-")) and not stripped.startswith("-"):
            break

        if stripped.startswith("-"):
            table = strip_inline_comment(stripped[1:])
            if table:
                tables.append(table)

    return tables


def dict_candidates(root, table):
    table_path = Path(table)
    candidates = []

    if table_path.suffix in {".yaml", ".yml"}:
        candidates.append(root / table_path)
    else:
        candidates.extend(root / directory / f"{table}.dict.yaml" for directory in SEARCH_DIRS)
        candidates.extend(root / directory / f"{table}.yaml" for directory in SEARCH_DIRS)

    return candidates


def resolve_dict_path(root, table):
    for candidate in dict_candidates(root, table):
        if candidate.is_file():
            return candidate
    return None


def parse_columns(lines):
    columns = []
    in_columns = False

    for line in lines:
        stripped = line.strip()
        if stripped == "...":
            break
        if not stripped or stripped.startswith("#"):
            continue

        if stripped == "columns:":
            in_columns = True
            continue

        if in_columns:
            if stripped.startswith("-"):
                column = strip_inline_comment(stripped[1:])
                if column:
                    columns.append(column)
                continue
            break

    return columns


def data_start_index(lines):
    for index, line in enumerate(lines):
        if line.strip() == "...":
            return index + 1
    return 0


def parse_dict_entries(path):
    lines = read_lines(path)
    columns = parse_columns(lines)
    text_index = columns.index("text") if "text" in columns else 0
    code_index = columns.index("code") if "code" in columns else 1
    start_index = data_start_index(lines)

    for line_number, line in enumerate(lines[start_index:], start=start_index + 1):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        fields = line.rstrip("\r\n").split("\t")
        if len(fields) <= max(text_index, code_index):
            print(
                f"warning: skip malformed line {path}:{line_number}",
                file=sys.stderr,
            )
            continue

        text = fields[text_index].strip()
        code = fields[code_index].strip()
        if text and code:
            yield code, text


def merged_entries(root, extended_path, include_duplicates, strict):
    seen = set()
    missing_tables = []

    for table in parse_import_tables(extended_path):
        dict_path = resolve_dict_path(root, table)
        if dict_path is None:
            missing_tables.append(table)
            print(f"warning: dictionary not found: {table}", file=sys.stderr)
            continue

        for code, text in parse_dict_entries(dict_path):
            key = (code, text)
            if include_duplicates or key not in seen:
                if not include_duplicates:
                    seen.add(key)
                yield code, text

    if strict and missing_tables:
        raise SystemExit(f"missing dictionaries: {', '.join(missing_tables)}")


def write_output(entries, output_path):
    if output_path:
        with Path(output_path).open("w", encoding="utf-8") as output_file:
            for code, text in entries:
                output_file.write(f"{code}\t{text}\n")
    else:
        for code, text in entries:
            sys.stdout.write(f"{code}\t{text}\n")


def main():
    args = parse_args()
    root = repo_root()
    extended_path = Path(args.extended)
    if not extended_path.is_absolute():
        extended_path = root / extended_path

    if not extended_path.is_file():
        raise SystemExit(f"extended dictionary not found: {extended_path}")

    entries = merged_entries(root, extended_path, args.include_duplicates, args.strict)
    write_output(entries, args.output)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
import argparse
import re
import sys
import unicodedata
from pathlib import Path


REQUIRED_SECTION_SETS = (
    ("teoria", "esempio", "validazion", "troubleshoot"),
    ("obiettiv", "procedura operativa", "validazione finale", "troubleshoot"),
    ("obiettiv", "assessment", "procedur", "validazion", "troubleshoot"),
)


def normalize(text: str) -> str:
    ascii_text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    return re.sub(r"\s+", " ", ascii_text.strip().lower())


def extract_headings(content: str) -> set[str]:
    headings = set()
    for line in content.splitlines():
        match = re.match(r"^\s{0,3}#{1,6}\s+(.+?)\s*$", line)
        if match:
            headings.add(normalize(match.group(1)))
    return headings


def validate_file(path: Path) -> tuple[bool, list[str]]:
    if not path.exists():
        return False, [f"file non trovato: {path}"]
    headings = extract_headings(path.read_text(encoding="utf-8"))
    for required_set in REQUIRED_SECTION_SETS:
        if all(any(req in heading for heading in headings) for req in required_set):
            return True, []
    expected = [
        " + ".join(section_set) for section_set in REQUIRED_SECTION_SETS
    ]
    return False, [f"mancano sezioni obbligatorie (atteso uno dei set: {expected})"]


def main() -> int:
    parser = argparse.ArgumentParser(description="Valida la compliance didattica delle guide.")
    parser.add_argument("files", nargs="+", help="File markdown da validare")
    args = parser.parse_args()

    failed = False
    for file_arg in args.files:
        file_path = Path(file_arg)
        is_valid, errors = validate_file(file_path)
        if is_valid:
            print(f"[OK] {file_path}")
            continue
        failed = True
        print(f"[FAIL] {file_path}")
        for error in errors:
            print(f"  - {error}")

    if failed:
        print("\nCompliance didattica non soddisfatta.")
        return 1
    print("\nCompliance didattica soddisfatta.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

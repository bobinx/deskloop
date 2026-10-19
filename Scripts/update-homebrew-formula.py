#!/usr/bin/env python3

import argparse
import re
from pathlib import Path


def replace_once(content: str, pattern: str, replacement: str) -> str:
    updated, count = re.subn(pattern, replacement, content, count=1, flags=re.MULTILINE)
    if count != 1:
        raise ValueError(f"Expected exactly one formula line matching {pattern!r}")
    return updated


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("formula", type=Path)
    parser.add_argument("version")
    parser.add_argument("url")
    parser.add_argument("sha256")
    args = parser.parse_args()

    if not re.fullmatch(r"\d+\.\d+\.\d+", args.version):
        parser.error("version must use the format major.minor.patch")
    if not re.fullmatch(r"[0-9a-f]{64}", args.sha256):
        parser.error("sha256 must contain 64 lowercase hexadecimal characters")

    content = args.formula.read_text()
    content = replace_once(content, r'^  url ".*"$', f'  url "{args.url}"')
    content = replace_once(content, r'^  version ".*"$', f'  version "{args.version}"')
    content = replace_once(content, r'^  sha256 ".*"$', f'  sha256 "{args.sha256}"')
    args.formula.write_text(content)


if __name__ == "__main__":
    main()

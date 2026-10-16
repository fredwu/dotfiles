#!/usr/bin/env python3
"""Validate one exact terminal JSON review without starting a provider."""

import argparse
import sys
from pathlib import Path


def main():
    sys.dont_write_bytecode = True
    from acp_review import (
        SCHEMA_PATH,
        ReviewError,
        read_input,
        strict_json,
        validate_review_result,
    )

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = strict_json(
            read_input(args.input, "External review input exceeds the bounded size.")
        )
        schema = strict_json(SCHEMA_PATH.read_text(encoding="utf-8"))
        validate_review_result(result, schema)
    except (OSError, UnicodeError, ValueError, RecursionError, ReviewError):
        print("External review validation failed.", file=sys.stderr)
        return 2
    print(f"External review valid: {result['verdict']}.")
    return 1 if result["verdict"] == "incomplete" else 0


if __name__ == "__main__":
    sys.exit(main())

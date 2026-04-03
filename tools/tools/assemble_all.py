#!/usr/bin/env python3
"""Build all default HEX images from ASM sources used by tests."""

from __future__ import annotations

import pathlib
import subprocess
import sys


def run_assembler(repo_root: pathlib.Path, src: str, dst: str) -> None:
    cmd = [
        sys.executable,
        str(repo_root / "tools" / "tools" / "assembler.py"),
        str(repo_root / src),
        "-o",
        str(repo_root / dst),
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        if result.stdout:
            print(result.stdout, end="")
        if result.stderr:
            print(result.stderr, end="", file=sys.stderr)
        raise SystemExit(result.returncode)
    if result.stdout:
        print(result.stdout, end="")


def main() -> int:
    repo_root = pathlib.Path(__file__).resolve().parents[2]

    run_assembler(repo_root, "tests/asm/program_cpu.asm", "tests/program.hex")
    run_assembler(
        repo_root,
        "tests/asm/program_simple_com.asm",
        "tests/isa_tests/program_simple_com.hex",
    )
    run_assembler(repo_root, "tests/asm/program_bne_loop.asm", "tests/program_bne_loop.hex")

    print("All default HEX files were generated successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

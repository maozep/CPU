#!/usr/bin/env python3
"""One-button end-to-end verification flow for the Simple 8-bit CPU.

Flow:
1) Assemble default HEX files from ASM sources.
2) Compile and run all unit + ISA testbenches.
3) Print a clear PASS/FAIL summary and return non-zero on any failure.
"""

from __future__ import annotations

import pathlib
import subprocess
import sys
from dataclasses import dataclass
from typing import List, Optional, Sequence


@dataclass(frozen=True)
class TestCase:
    name: str
    compile_cmd: Sequence[str]
    run_cmd: Sequence[str]
    required_pass: Optional[str] = None


def run_command(cmd: Sequence[str], cwd: pathlib.Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=cwd,
        capture_output=True,
        text=True,
        shell=False,
    )


def print_section(title: str) -> None:
    print(f"\n=== {title} ===")


def has_fail_marker(output: str) -> bool:
    upper = output.upper()
    return "FAIL:" in upper or "RESULT: FAIL" in upper


def run_test(test: TestCase, repo_root: pathlib.Path) -> bool:
    print_section(f"TEST {test.name}")

    comp = run_command(test.compile_cmd, repo_root)
    if comp.stdout:
        print(comp.stdout, end="")
    if comp.stderr:
        print(comp.stderr, end="", file=sys.stderr)
    if comp.returncode != 0:
        print(f"[FAIL] {test.name}: compile step failed with code {comp.returncode}")
        return False

    run = run_command(test.run_cmd, repo_root)
    output = (run.stdout or "") + (run.stderr or "")
    if run.stdout:
        print(run.stdout, end="")
    if run.stderr:
        print(run.stderr, end="", file=sys.stderr)

    if run.returncode != 0:
        print(f"[FAIL] {test.name}: run step failed with code {run.returncode}")
        return False

    if has_fail_marker(output):
        print(f"[FAIL] {test.name}: detected FAIL marker in simulation output")
        return False

    if test.required_pass and test.required_pass not in output:
        print(f"[FAIL] {test.name}: required pass marker not found: {test.required_pass}")
        return False

    print(f"[PASS] {test.name}")
    return True


def main() -> int:
    repo_root = pathlib.Path(__file__).resolve().parents[2]
    python_exe = pathlib.Path(sys.executable)

    print_section("ASSEMBLE")
    assemble_cmd = [str(python_exe), str(repo_root / "tools" / "tools" / "assemble_all.py")]
    assemble = run_command(assemble_cmd, repo_root)
    if assemble.stdout:
        print(assemble.stdout, end="")
    if assemble.stderr:
        print(assemble.stderr, end="", file=sys.stderr)
    if assemble.returncode != 0:
        print(f"[FAIL] Assemble step failed with code {assemble.returncode}")
        return assemble.returncode
    print("[PASS] Assemble step")

    tests: List[TestCase] = [
        TestCase(
            name="tb_alu",
            compile_cmd=["iverilog", "-o", "sim/alu_sim", "tests/unit_tests/tb_alu.v", "src/alu.v"],
            run_cmd=["vvp", "sim/alu_sim"],
            required_pass="PASS:",
        ),
        TestCase(
            name="tb_control_unit",
            compile_cmd=["iverilog", "-o", "sim/cu_sim", "tests/unit_tests/tb_control_unit.v", "src/control_unit.v"],
            run_cmd=["vvp", "sim/cu_sim"],
            required_pass="PASS: control_unit tests passed.",
        ),
        TestCase(
            name="tb_pc",
            compile_cmd=["iverilog", "-o", "sim/pc_sim", "tests/unit_tests/tb_pc.v", "src/pc.v"],
            run_cmd=["vvp", "sim/pc_sim"],
            required_pass="Simulation complete.",
        ),
        TestCase(
            name="tb_regfile",
            compile_cmd=["iverilog", "-o", "sim/regfile_sim", "tests/unit_tests/tb_regfile.v", "src/regfile.v"],
            run_cmd=["vvp", "sim/regfile_sim"],
            required_pass="PASS:",
        ),
        TestCase(
            name="tb_imem",
            compile_cmd=["iverilog", "-o", "sim/imem_sim", "tests/unit_tests/tb_imem.v", "src/imem.v"],
            run_cmd=["vvp", "sim/imem_sim"],
            required_pass="EDGE [Wrap-around / reset to start]",
        ),
        TestCase(
            name="tb_cpu",
            compile_cmd=[
                "iverilog",
                "-o",
                "sim/cpu_sim",
                "tests/unit_tests/tb_cpu.v",
                "src/cpu.v",
                "src/pc.v",
                "src/imem.v",
                "src/control_unit.v",
                "src/regfile.v",
                "src/alu.v",
            ],
            run_cmd=["vvp", "sim/cpu_sim"],
            required_pass="PASS: program.hex reached HALT with expected register values.",
        ),
        TestCase(
            name="tb_simple_com",
            compile_cmd=[
                "iverilog",
                "-o",
                "sim/sim_cpu",
                "tests/isa_tests/tb_simple_com.v",
                "src/cpu.v",
                "src/pc.v",
                "src/imem.v",
                "src/control_unit.v",
                "src/regfile.v",
                "src/alu.v",
            ],
            run_cmd=["vvp", "sim/sim_cpu"],
            required_pass="RESULT: PASS -- all ISA operations verified.",
        ),
    ]

    print_section("SIMULATION")
    failures: List[str] = []
    for test in tests:
        ok = run_test(test, repo_root)
        if not ok:
            failures.append(test.name)

    print_section("SUMMARY")
    if failures:
        print(f"FAILED TESTS ({len(failures)}): {', '.join(failures)}")
        return 1

    print(f"ALL TESTS PASSED ({len(tests)}/{len(tests)})")
    print("E2E RESULT: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

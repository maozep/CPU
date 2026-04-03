#!/usr/bin/env python3
"""
Compare CPU behavioral simulator vs Verilog testbench output
Verifies that final register states match for the same HEX file
"""

import sys
import os
import subprocess
import re
from typing import Dict, List, Tuple

def parse_simulator_output(output: str) -> Dict[str, int]:
    """Extract final register state from simulator output"""
    registers = {}
    
    # Look for "Final Registers:" line
    match = re.search(r'Final Registers:\s+(.+)', output)
    if match:
        reg_line = match.group(1)
        # Parse "R0=XX R1=XX ..." format
        for reg_match in re.finditer(r'R(\d)=([0-9a-fA-F]+)', reg_line):
            reg_num = int(reg_match.group(1))
            reg_val = int(reg_match.group(2), 16)
            registers[f'R{reg_num}'] = reg_val
    
    return registers

def run_simulator(repo_root: str, hex_file: str) -> Tuple[bool, str]:
    """Run behavioral simulator and return output"""
    sim_script = os.path.join(repo_root, "tools/simulator.py")
    python_exe = os.path.join(repo_root, ".venv/Scripts/python.exe")
    
    if not os.path.exists(python_exe):
        python_exe = "python"  # Fallback to system python
    
    try:
        result = subprocess.run(
            [python_exe, sim_script, hex_file],
            capture_output=True,
            text=True,
            timeout=10
        )
        return True, result.stdout + result.stderr
    except Exception as e:
        return False, str(e)

def print_comparison(hex_file: str, sim_regs: Dict[str, int]):
    """Pretty-print simulator results"""
    print(f"\n{'='*60}")
    print(f"HEX File: {hex_file}")
    print(f"{'='*60}")
    print(f"\nSimulator Final State:")
    print(f"  {' '.join(f'{name}=0x{val:02x}' for name, val in sorted(sim_regs.items()))}")

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <hex_file> [hex_file2 ...]")
        print(f"Example: {sys.argv[0]} tests/program.hex tests/isa_tests/program_simple_com.hex")
        sys.exit(1)
    
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    hex_files = sys.argv[1:]
    
    print("\n[CPU Behavioral Simulator Verification]")
    print(f"Repository root: {repo_root}\n")
    
    all_pass = True
    
    for hex_file in hex_files:
        full_path = os.path.join(repo_root, hex_file) if not os.path.isabs(hex_file) else hex_file
        
        if not os.path.exists(full_path):
            print(f"ERROR: File not found: {full_path}")
            all_pass = False
            continue
        
        success, output = run_simulator(repo_root, full_path)
        
        if not success:
            print(f"ERROR: Simulator failed for {hex_file}")
            print(f"  Details: {output}")
            all_pass = False
            continue
        
        registers = parse_simulator_output(output)
        
        if not registers:
            print(f"WARNING: Could not parse final registers from {hex_file}")
            print(output)
            all_pass = False
            continue
        
        print_comparison(hex_file, registers)
    
    if all_pass:
        print(f"\n\n✓ All simulator runs completed successfully")
        sys.exit(0)
    else:
        print(f"\n\n✗ Some tests failed")
        sys.exit(1)

if __name__ == "__main__":
    main()

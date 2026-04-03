#!/usr/bin/env python3
"""
C++ RISC CPU Behavioral Simulator (Golden Model)
Executes 16-bit RISC instructions from HEX files
Python version for immediate execution (C++ version also available)
"""

import sys
import struct
from typing import Dict, List, Tuple

class CPUSimulator:
    def __init__(self):
        self.registers = [0] * 8          # R0-R7, 8-bit
        self.imem = [0] * 256             # Instruction memory, 16-bit words
        self.pc = 0                       # Program counter, 8-bit
        self.halted = False               # HALT flag
        self.instruction_count = 0        # Execution counter
    
    def load_hex(self, filename: str) -> bool:
        """Load HEX file into instruction memory"""
        try:
            with open(filename, 'r') as f:
                address = 0
                for line_num, line in enumerate(f, 1):
                    # Remove comments
                    if '//' in line:
                        line = line[:line.index('//')]
                    
                    line = line.strip()
                    if not line:
                        continue
                    
                    try:
                        value = int(line, 16)
                        if value > 0xFFFF:
                            print(f"[LOADER] Warning: Value 0x{value:04X} exceeds 16-bit on line {line_num}")
                        self.imem[address] = value & 0xFFFF
                        address += 1
                        if address >= 256:
                            break
                    except ValueError:
                        print(f"[LOADER] Warning: Invalid hex value '{line}' on line {line_num}")
            
            print(f"[LOADER] Loaded {address} instructions from {filename}")
            return True
        except FileNotFoundError:
            print(f"[ERROR] Cannot open file: {filename}")
            return False
        except Exception as e:
            print(f"[ERROR] Exception loading file: {e}")
            return False
    
    def extract_bits(self, value: int, high: int, low: int) -> int:
        """Extract bits [high:low] from value"""
        width = high - low + 1
        return (value >> low) & ((1 << width) - 1)
    
    def sign_extend(self, value: int, width: int) -> int:
        """Sign-extend a value from given width to 32-bit signed int"""
        if value & (1 << (width - 1)):
            # Sign bit is set; extend with 1s
            return value | ((-1) << width)
        return value
    
    def fetch(self) -> int:
        """Fetch instruction at current PC"""
        return self.imem[self.pc]
    
    def execute_alu(self, instr: int, op: str):
        """Execute ALU instruction (ADD, SUB, AND, OR)"""
        rd = self.extract_bits(instr, 11, 9)
        rs1 = self.extract_bits(instr, 8, 6)
        rs2 = self.extract_bits(instr, 5, 3)
        
        val1 = self.registers[rs1]
        val2 = self.registers[rs2]
        
        if op == '+':
            result = (val1 + val2) & 0xFF
            print(f"ADD R{rd} = R{rs1}({val1}) + R{rs2}({val2}) = {result}", end="")
        elif op == '-':
            result = (val1 - val2) & 0xFF
            print(f"SUB R{rd} = R{rs1}({val1}) - R{rs2}({val2}) = {result}", end="")
        elif op == '&':
            result = val1 & val2
            print(f"AND R{rd} = R{rs1}({val1}) & R{rs2}({val2}) = {result}", end="")
        elif op == '|':
            result = val1 | val2
            print(f"OR  R{rd} = R{rs1}({val1}) | R{rs2}({val2}) = {result}", end="")
        
        self.registers[rd] = result
        self.pc = (self.pc + 1) & 0xFF
        print()
    
    def execute_branch(self, instr: int, is_beq: bool):
        """Execute branch instruction (BEQ or BNE)"""
        rs1 = self.extract_bits(instr, 11, 9)
        rs2 = self.extract_bits(instr, 8, 6)
        offset_raw = self.extract_bits(instr, 5, 0)
        
        # Sign-extend 6-bit offset to signed integer
        offset = self.sign_extend(offset_raw, 6)
        
        val1 = self.registers[rs1]
        val2 = self.registers[rs2]
        
        if is_beq:
            branch_taken = (val1 == val2)
            print(f"BEQ R{rs1}({val1}) == R{rs2}({val2}) ? ", end="")
        else:
            branch_taken = (val1 != val2)
            print(f"BNE R{rs1}({val1}) != R{rs2}({val2}) ? ", end="")
        
        next_pc = (self.pc + 1) & 0xFF
        
        if branch_taken:
            next_pc = (next_pc + offset) & 0xFF
            print(f"YES -> PC = {(self.pc + 1) & 0xFF} + {offset} = {next_pc}")
        else:
            print(f"NO -> PC = {next_pc}")
        
        self.pc = next_pc
    
    def execute_halt(self):
        """Execute HALT instruction"""
        print("HALT -- Execution stopped")
        self.halted = True
    
    def execute(self, instr: int):
        """Decode and execute instruction"""
        opcode = self.extract_bits(instr, 15, 12)
        
        print(f"[PC={self.pc:02x} | Instr=0x{instr:04x}] ", end="")
        
        if opcode == 0x0:      # HALT
            self.execute_halt()
        elif opcode == 0x1:    # ADD
            self.execute_alu(instr, '+')
        elif opcode == 0x2:    # SUB
            self.execute_alu(instr, '-')
        elif opcode == 0x3:    # AND
            self.execute_alu(instr, '&')
        elif opcode == 0x4:    # OR
            self.execute_alu(instr, '|')
        elif opcode == 0x5:    # BEQ
            self.execute_branch(instr, True)
        elif opcode == 0x6:    # BNE
            self.execute_branch(instr, False)
        else:
            print(f"UNKNOWN OPCODE 0x{opcode:x}")
    
    def print_registers(self):
        """Print current register file state"""
        reg_str = "  Registers: " + " ".join(f"R{i}={self.registers[i]:02x}" for i in range(8))
        print(reg_str)
    
    def run(self):
        """Execute fetch-decode-execute loop"""
        print("\n=== Starting CPU Simulation ===")
        print(f"Initial PC: {self.pc}\n")
        
        while not self.halted and self.pc < 256:
            self.print_registers()
            instr = self.fetch()
            self.execute(instr)
            self.instruction_count += 1
        
        print("\n=== Simulation Complete ===")
        print(f"Total instructions executed: {self.instruction_count}")
        print(f"Final PC: {self.pc}")
        print("Final Registers: " + " ".join(f"R{i}={self.registers[i]:02x}" for i in range(8)))


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <hex_file>")
        print(f"Example: {sys.argv[0]} program.hex")
        sys.exit(1)
    
    hex_file = sys.argv[1]
    cpu = CPUSimulator()
    
    if not cpu.load_hex(hex_file):
        sys.exit(1)
    
    cpu.run()


if __name__ == "__main__":
    main()

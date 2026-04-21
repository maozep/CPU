#!/usr/bin/env python3
"""
C++ RISC CPU Behavioral Simulator (Golden Model)
Executes 16-bit RISC instructions from HEX files
Python version for immediate execution (C++ version also available)
"""

import sys
from typing import List

class CPUSimulator:
    def __init__(self):
        self.registers = [0] * 8          # R0-R7, 8-bit
        self.imem = [0] * 256             # Instruction memory, 16-bit words
        self.dmem = [0] * 256             # Data memory, 8-bit words
        self.pc = 0                       # Program counter, 8-bit
        self.halted = False               # HALT flag
        self.instruction_count = 0        # Execution counter
        self.trace_enabled = True         # Verbose trace print flag

    def reset(self):
        self.registers = [0] * 8
        self.imem = [0] * 256
        self.dmem = [0] * 256
        self.pc = 0
        self.halted = False
        self.instruction_count = 0

    def set_trace(self, enabled: bool):
        self.trace_enabled = enabled

    def load_program(self, words: List[int]):
        self.reset()
        for i, word in enumerate(words[:256]):
            self.imem[i] = word & 0xFFFF

    def set_register(self, idx: int, value: int):
        if 0 <= idx < 8 and idx != 0:
            self.registers[idx] = value & 0xFF

    def seed_demo_registers(self):
        for i in range(1, 8):
            self.registers[i] = i
    
    def load_hex(self, filename: str) -> bool:
        """Load HEX file into instruction memory"""
        self.reset()
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
            
            if self.trace_enabled:
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
    
    def execute_addi(self, instr: int):
        """Execute ADDI instruction: rd = rs1 + sign_extend(imm6)"""
        rd  = self.extract_bits(instr, 11, 9)
        rs1 = self.extract_bits(instr, 8, 6)
        imm6_raw = self.extract_bits(instr, 5, 0)
        imm6 = self.sign_extend(imm6_raw, 6)
        val1 = self.registers[rs1]
        result = (val1 + imm6) & 0xFF
        if self.trace_enabled:
            print(f"ADDI R{rd} = R{rs1}({val1}) + {imm6} = {result}")
        self.registers[rd] = result
        self.pc = (self.pc + 1) & 0xFF

    def execute_alu(self, instr: int, op: str):
        """Execute ALU instruction (ADD, SUB, AND, OR)"""
        rd = self.extract_bits(instr, 11, 9)
        rs1 = self.extract_bits(instr, 8, 6)
        rs2 = self.extract_bits(instr, 5, 3)

        val1 = self.registers[rs1]
        val2 = self.registers[rs2]
        
        if op == '+':
            result = (val1 + val2) & 0xFF
            if self.trace_enabled:
                print(f"ADD R{rd} = R{rs1}({val1}) + R{rs2}({val2}) = {result}", end="")
        elif op == '-':
            result = (val1 - val2) & 0xFF
            if self.trace_enabled:
                print(f"SUB R{rd} = R{rs1}({val1}) - R{rs2}({val2}) = {result}", end="")
        elif op == '&':
            result = val1 & val2
            if self.trace_enabled:
                print(f"AND R{rd} = R{rs1}({val1}) & R{rs2}({val2}) = {result}", end="")
        elif op == '|':
            result = val1 | val2
            if self.trace_enabled:
                print(f"OR  R{rd} = R{rs1}({val1}) | R{rs2}({val2}) = {result}", end="")
        elif op == '^':
            result = val1 ^ val2
            if self.trace_enabled:
                print(f"XOR R{rd} = R{rs1}({val1}) ^ R{rs2}({val2}) = {result}", end="")
        elif op == '<<':
            shift = val2 & 0x7
            result = (val1 << shift) & 0xFF
            if self.trace_enabled:
                print(f"SLL R{rd} = R{rs1}({val1}) << R{rs2}({shift}) = {result}", end="")
        elif op == '>>':
            shift = val2 & 0x7
            result = (val1 >> shift) & 0xFF
            if self.trace_enabled:
                print(f"SRL R{rd} = R{rs1}({val1}) >> R{rs2}({shift}) = {result}", end="")
        elif op == '>>>':
            shift = val2 & 0x7
            # Arithmetic shift: sign-extend from bit 7
            if val1 & 0x80:
                # Negative: shift right and fill with 1s
                result = ((val1 | 0xFF00) >> shift) & 0xFF
            else:
                result = (val1 >> shift) & 0xFF
            if self.trace_enabled:
                print(f"SRA R{rd} = R{rs1}({val1}) >>> R{rs2}({shift}) = {result}", end="")
        
        self.registers[rd] = result
        self.pc = (self.pc + 1) & 0xFF
        if self.trace_enabled:
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
            if self.trace_enabled:
                print(f"BEQ R{rs1}({val1}) == R{rs2}({val2}) ? ", end="")
        else:
            branch_taken = (val1 != val2)
            if self.trace_enabled:
                print(f"BNE R{rs1}({val1}) != R{rs2}({val2}) ? ", end="")
        
        next_pc = (self.pc + 1) & 0xFF
        
        if branch_taken:
            next_pc = (next_pc + offset) & 0xFF
            if self.trace_enabled:
                print(f"YES -> PC = {(self.pc + 1) & 0xFF} + {offset} = {next_pc}")
        else:
            if self.trace_enabled:
                print(f"NO -> PC = {next_pc}")
        
        self.pc = next_pc
    
    def execute_lw(self, instr: int):
        """Execute LW instruction: rd = DMEM[rs1 + sign_extend(imm6)]"""
        rd  = self.extract_bits(instr, 11, 9)
        rs1 = self.extract_bits(instr, 8, 6)
        imm6_raw = self.extract_bits(instr, 5, 0)
        imm6 = self.sign_extend(imm6_raw, 6)
        addr = (self.registers[rs1] + imm6) & 0xFF
        result = self.dmem[addr]
        if self.trace_enabled:
            print(f"LW  R{rd} = DMEM[R{rs1}({self.registers[rs1]}) + {imm6}] = DMEM[{addr}] = {result}")
        self.registers[rd] = result
        self.pc = (self.pc + 1) & 0xFF

    def execute_sw(self, instr: int):
        """Execute SW instruction: DMEM[rs1 + sign_extend(imm6)] = rs2"""
        rs2 = self.extract_bits(instr, 11, 9)  # data source
        rs1 = self.extract_bits(instr, 8, 6)   # base address
        imm6_raw = self.extract_bits(instr, 5, 0)
        imm6 = self.sign_extend(imm6_raw, 6)
        addr = (self.registers[rs1] + imm6) & 0xFF
        data = self.registers[rs2]
        if self.trace_enabled:
            print(f"SW  DMEM[R{rs1}({self.registers[rs1]}) + {imm6}] = DMEM[{addr}] = R{rs2}({data})")
        self.dmem[addr] = data
        self.pc = (self.pc + 1) & 0xFF

    def execute_jmp(self, instr: int):
        """Execute JMP instruction: unconditional relative jump"""
        offset_raw = self.extract_bits(instr, 5, 0)
        offset = self.sign_extend(offset_raw, 6)
        next_pc = (self.pc + 1 + offset) & 0xFF
        if self.trace_enabled:
            print(f"JMP offset={offset} -> PC = {(self.pc + 1) & 0xFF} + {offset} = {next_pc}")
        self.pc = next_pc

    def execute_slti(self, instr: int):
        """Execute SLTI instruction: rd = (rs1 < sign_extend(imm6)) ? 1 : 0 (signed)"""
        rd  = self.extract_bits(instr, 11, 9)
        rs1 = self.extract_bits(instr, 8, 6)
        imm6_raw = self.extract_bits(instr, 5, 0)
        imm6 = self.sign_extend(imm6_raw, 6)
        # Signed comparison: treat 8-bit register as signed
        val1 = self.registers[rs1]
        if val1 >= 128:
            val1_signed = val1 - 256
        else:
            val1_signed = val1
        result = 1 if val1_signed < imm6 else 0
        if self.trace_enabled:
            print(f"SLTI R{rd} = (R{rs1}({self.registers[rs1]}) < {imm6}) ? 1 : 0 = {result}")
        self.registers[rd] = result
        self.pc = (self.pc + 1) & 0xFF

    def execute_halt(self):
        """Execute HALT instruction"""
        if self.trace_enabled:
            print("HALT -- Execution stopped")
        self.halted = True
    
    def execute(self, instr: int):
        """Decode and execute instruction"""
        opcode = self.extract_bits(instr, 15, 12)
        
        if self.trace_enabled:
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
        elif opcode == 0xB:    # XOR
            self.execute_alu(instr, '^')
        elif opcode == 0xC:    # SLL
            self.execute_alu(instr, '<<')
        elif opcode == 0xD:    # SRL
            self.execute_alu(instr, '>>')
        elif opcode == 0xE:    # SRA
            self.execute_alu(instr, '>>>')
        elif opcode == 0x5:    # BEQ
            self.execute_branch(instr, True)
        elif opcode == 0x6:    # BNE
            self.execute_branch(instr, False)
        elif opcode == 0x7:    # ADDI
            self.execute_addi(instr)
        elif opcode == 0x8:    # LW
            self.execute_lw(instr)
        elif opcode == 0x9:    # SW
            self.execute_sw(instr)
        elif opcode == 0xA:    # JMP
            self.execute_jmp(instr)
        elif opcode == 0xF:    # SLTI
            self.execute_slti(instr)
        else:
            if self.trace_enabled:
                print(f"UNKNOWN OPCODE 0x{opcode:x}")
    
    def print_registers(self):
        """Print current register file state"""
        reg_str = "  Registers: " + " ".join(f"R{i}={self.registers[i]:02x}" for i in range(8))
        print(reg_str)
    
    def run(self, max_steps: int = 10000) -> bool:
        """Execute fetch-decode-execute loop"""
        if self.trace_enabled:
            print("\n=== Starting CPU Simulation ===")
            print(f"Initial PC: {self.pc}\n")
        
        while not self.halted and self.pc < 256 and self.instruction_count < max_steps:
            if self.trace_enabled:
                self.print_registers()
            instr = self.fetch()
            self.execute(instr)
            self.instruction_count += 1

        completed_by_halt = self.halted
        if not completed_by_halt and self.trace_enabled:
            print(f"[WARN] Stopped due to max_steps={max_steps}")
        
        if self.trace_enabled:
            print("\n=== Simulation Complete ===")
            print(f"Total instructions executed: {self.instruction_count}")
            print(f"Final PC: {self.pc}")
            print("Final Registers: " + " ".join(f"R{i}={self.registers[i]:02x}" for i in range(8)))

        return completed_by_halt


def encode_rtype(opcode: int, rd: int, rs1: int, rs2: int) -> int:
    return ((opcode & 0xF) << 12) | ((rd & 0x7) << 9) | ((rs1 & 0x7) << 6) | ((rs2 & 0x7) << 3)


def encode_branch(opcode: int, rs1: int, rs2: int, offset6: int) -> int:
    return ((opcode & 0xF) << 12) | ((rs1 & 0x7) << 9) | ((rs2 & 0x7) << 6) | (offset6 & 0x3F)


def encode_itype(opcode: int, rd: int, rs1: int, imm6: int) -> int:
    return ((opcode & 0xF) << 12) | ((rd & 0x7) << 9) | ((rs1 & 0x7) << 6) | (imm6 & 0x3F)


def run_self_tests() -> int:
    tests = []

    def test_alu_sequence():
        cpu = CPUSimulator()
        cpu.set_trace(False)
        cpu.load_program([
            encode_rtype(0x1, 3, 1, 2),
            encode_rtype(0x2, 4, 3, 2),
            encode_rtype(0x3, 5, 3, 2),
            encode_rtype(0x4, 6, 4, 2),
            0x0000,
        ])
        cpu.set_register(1, 5)
        cpu.set_register(2, 2)
        assert cpu.run()
        assert cpu.registers[3] == 7
        assert cpu.registers[4] == 5
        assert cpu.registers[5] == 2
        assert cpu.registers[6] == 7

    def test_beq_taken_skip():
        cpu = CPUSimulator()
        cpu.set_trace(False)
        cpu.load_program([
            encode_branch(0x5, 1, 2, 1),
            encode_rtype(0x1, 3, 1, 1),
            encode_rtype(0x1, 4, 1, 2),
            0x0000,
        ])
        cpu.set_register(1, 9)
        cpu.set_register(2, 9)
        assert cpu.run()
        assert cpu.registers[3] == 0
        assert cpu.registers[4] == 18

    def test_bne_negative_loop():
        cpu = CPUSimulator()
        cpu.set_trace(False)
        cpu.load_program([
            encode_rtype(0x2, 1, 1, 7),
            encode_branch(0x6, 1, 0, -2),
            0x0000,
        ])
        cpu.set_register(1, 3)
        cpu.set_register(7, 1)
        assert cpu.run()
        assert cpu.registers[1] == 0
        assert cpu.pc == 2

    def test_max_steps_guard():
        cpu = CPUSimulator()
        cpu.set_trace(False)
        cpu.load_program([
            encode_branch(0x6, 1, 0, -1),
            0x0000,
        ])
        cpu.set_register(1, 1)
        halted = cpu.run(max_steps=20)
        assert halted is False
        assert cpu.pc == 0
        assert cpu.instruction_count == 20

    def test_addi():
        cpu = CPUSimulator()
        cpu.set_trace(False)
        cpu.load_program([
            encode_itype(0x7, 2, 1, 10),   # R2 = R1 + 10  (5+10=15)
            encode_itype(0x7, 3, 1, -3),   # R3 = R1 + (-3) (5-3=2)
            encode_itype(0x7, 4, 0, 7),    # R4 = R0 + 7   (0+7=7)
            encode_itype(0x7, 5, 2, 31),   # R5 = R2 + 31  (15+31=46)
            encode_itype(0x7, 6, 2, -32),  # R6 = R2 + (-32) (15-32= wrap 239)
            0x0000,
        ])
        cpu.set_register(1, 5)
        assert cpu.run()
        assert cpu.registers[2] == 15,  f"R2={cpu.registers[2]}"
        assert cpu.registers[3] == 2,   f"R3={cpu.registers[3]}"
        assert cpu.registers[4] == 7,   f"R4={cpu.registers[4]}"
        assert cpu.registers[5] == 46,  f"R5={cpu.registers[5]}"
        assert cpu.registers[6] == 239, f"R6={cpu.registers[6]}"

    def test_lw_sw():
        cpu = CPUSimulator()
        cpu.set_trace(False)
        cpu.load_program([
            encode_itype(0x7, 1, 0, 25),   # R1 = 25
            encode_itype(0x7, 2, 0, 10),   # R2 = 10
            encode_itype(0x9, 1, 0, 0),    # SW R1 -> DMEM[0] = 25
            encode_itype(0x9, 2, 0, 5),    # SW R2 -> DMEM[5] = 10
            encode_itype(0x8, 3, 0, 0),    # LW R3 = DMEM[0] = 25
            encode_itype(0x8, 4, 0, 5),    # LW R4 = DMEM[5] = 10
            encode_itype(0x8, 5, 0, 1),    # LW R5 = DMEM[1] = 0 (unwritten)
            0x0000,
        ])
        assert cpu.run()
        assert cpu.registers[3] == 25, f"R3={cpu.registers[3]}"
        assert cpu.registers[4] == 10, f"R4={cpu.registers[4]}"
        assert cpu.registers[5] == 0,  f"R5={cpu.registers[5]}"
        assert cpu.dmem[0] == 25, f"DMEM[0]={cpu.dmem[0]}"
        assert cpu.dmem[5] == 10, f"DMEM[5]={cpu.dmem[5]}"

    def test_jmp():
        cpu = CPUSimulator()
        cpu.set_trace(False)
        cpu.load_program([
            encode_itype(0x7, 1, 0, 5),    # PC=0: ADDI R1, R0, 5
            encode_branch(0xA, 0, 0, 1),    # PC=1: JMP +1 (skip PC=2)
            encode_itype(0x7, 4, 0, 20),    # PC=2: ADDI R4, R0, 20 (SKIPPED)
            encode_branch(0xA, 0, 0, 2),    # PC=3: JMP +2 (skip to PC=6)
            encode_itype(0x7, 5, 0, 20),    # PC=4: ADDI R5, R0, 20 (via backward)
            0x0000,                          # PC=5: HALT
            encode_itype(0x7, 3, 0, 10),    # PC=6: ADDI R3, R0, 10
            encode_branch(0xA, 0, 0, -4),   # PC=7: JMP -4 (to PC=4)
        ])
        assert cpu.run()
        assert cpu.registers[1] == 5,  f"R1={cpu.registers[1]}"
        assert cpu.registers[3] == 10, f"R3={cpu.registers[3]}"
        assert cpu.registers[4] == 0,  f"R4={cpu.registers[4]}"
        assert cpu.registers[5] == 20, f"R5={cpu.registers[5]}"

    def test_xor():
        cpu = CPUSimulator()
        cpu.set_trace(False)
        cpu.load_program([
            encode_rtype(0xB, 3, 1, 2),  # R3 = R1 ^ R2
            encode_rtype(0xB, 4, 1, 1),  # R4 = R1 ^ R1 (should be 0)
            encode_rtype(0xB, 5, 1, 0),  # R5 = R1 ^ R0 (should be R1)
            0x0000,
        ])
        cpu.set_register(1, 0xA5)
        cpu.set_register(2, 0x5A)
        assert cpu.run()
        assert cpu.registers[3] == 0xFF, f"R3={cpu.registers[3]}"
        assert cpu.registers[4] == 0x00, f"R4={cpu.registers[4]}"
        assert cpu.registers[5] == 0xA5, f"R5={cpu.registers[5]}"

    def test_sll():
        cpu = CPUSimulator()
        cpu.set_trace(False)
        cpu.load_program([
            encode_rtype(0xC, 3, 1, 2),  # R3 = R1 << R2 (1 << 3 = 8)
            encode_rtype(0xC, 4, 1, 3),  # R4 = R1 << R3 (1 << 0 = 1, R3=8 -> 8&7=0)
            encode_rtype(0xC, 5, 2, 6),  # R5 = R2 << R6 (0xA5 << 4 = 0x50)
            encode_rtype(0xC, 6, 1, 0),  # R6 = R1 << R0 (1 << 0 = 1)
            0x0000,
        ])
        cpu.set_register(1, 1)
        cpu.set_register(2, 0xA5)
        cpu.set_register(3, 8)     # shift by 8 -> &7 = 0
        cpu.set_register(6, 4)
        assert cpu.run()
        # R3 = 1 << (0xA5 & 7) = 1 << 5 = 32
        assert cpu.registers[3] == 32, f"R3={cpu.registers[3]}"
        # R4 = 1 << (32 & 7) = 1 << 0 = 1
        assert cpu.registers[4] == 1, f"R4={cpu.registers[4]}"
        # R5 = 0xA5 << (4 & 7) = 0xA5 << 4 = 0x50 (truncated to 8-bit)
        assert cpu.registers[5] == 0x50, f"R5={cpu.registers[5]}"
        # R6 = 1 << 0 = 1
        assert cpu.registers[6] == 1, f"R6={cpu.registers[6]}"

    def test_srl():
        cpu = CPUSimulator()
        cpu.set_trace(False)
        cpu.load_program([
            encode_rtype(0xD, 3, 1, 2),  # R3 = R1 >> R2
            encode_rtype(0xD, 4, 1, 3),  # R4 = R1 >> R3
            encode_rtype(0xD, 5, 1, 0),  # R5 = R1 >> R0 (no shift)
            0x0000,
        ])
        cpu.set_register(1, 0x80)
        cpu.set_register(2, 1)
        cpu.set_register(3, 4)
        assert cpu.run()
        # R3 = 0x80 >> (1 & 7) = 0x40
        assert cpu.registers[3] == 0x40, f"R3={cpu.registers[3]}"
        # R4 = 0x80 >> (0x40 & 7) = 0x80 >> 0 = 0x80
        assert cpu.registers[4] == 0x80, f"R4={cpu.registers[4]}"
        # R5 = 0x80 >> 0 = 0x80
        assert cpu.registers[5] == 0x80, f"R5={cpu.registers[5]}"

    def test_sra():
        cpu = CPUSimulator()
        cpu.set_trace(False)
        cpu.load_program([
            encode_rtype(0xE, 3, 1, 2),  # R3 = R1 >>> R2 (0x80 >>> 1 = 0xC0)
            encode_rtype(0xE, 4, 1, 3),  # R4 = R1 >>> R3 (0x80 >>> (0xC0&7=0) = 0x80)
            encode_rtype(0xE, 5, 1, 6),  # R5 = R1 >>> R6 (0x80 >>> 7 = 0xFF)
            encode_rtype(0xE, 6, 7, 2),  # R6 = R7 >>> R2 (0x7F >>> 1 = 0x3F, positive)
            encode_rtype(0xE, 7, 1, 0),  # R7 = R1 >>> R0 (0x80 >>> 0 = 0x80)
            0x0000,
        ])
        cpu.set_register(1, 0x80)  # negative (bit 7 set)
        cpu.set_register(2, 1)
        cpu.set_register(6, 7)
        cpu.set_register(7, 0x7F)  # positive (bit 7 clear)
        assert cpu.run()
        assert cpu.registers[3] == 0xC0, f"R3={cpu.registers[3]:#x}"
        assert cpu.registers[4] == 0x80, f"R4={cpu.registers[4]:#x}"
        assert cpu.registers[5] == 0xFF, f"R5={cpu.registers[5]:#x}"
        assert cpu.registers[6] == 0x3F, f"R6={cpu.registers[6]:#x}"
        assert cpu.registers[7] == 0x80, f"R7={cpu.registers[7]:#x}"

    def test_slti():
        cpu = CPUSimulator()
        cpu.set_trace(False)
        cpu.load_program([
            encode_itype(0xF, 3, 1, 10),   # R3 = (R1 < 10) ? 1 : 0  (5 < 10 = 1)
            encode_itype(0xF, 4, 1, 5),    # R4 = (R1 < 5)  ? 1 : 0  (5 < 5 = 0)
            encode_itype(0xF, 5, 1, 3),    # R5 = (R1 < 3)  ? 1 : 0  (5 < 3 = 0)
            encode_itype(0xF, 6, 2, 0),    # R6 = (R2 < 0)  ? 1 : 0  (0x80=-128 < 0 = 1, signed)
            encode_itype(0xF, 7, 1, -1),   # R7 = (R1 < -1) ? 1 : 0  (5 < -1 = 0, signed)
            0x0000,
        ])
        cpu.set_register(1, 5)
        cpu.set_register(2, 0x80)  # -128 in signed
        assert cpu.run()
        assert cpu.registers[3] == 1, f"R3={cpu.registers[3]}"
        assert cpu.registers[4] == 0, f"R4={cpu.registers[4]}"
        assert cpu.registers[5] == 0, f"R5={cpu.registers[5]}"
        assert cpu.registers[6] == 1, f"R6={cpu.registers[6]}"
        assert cpu.registers[7] == 0, f"R7={cpu.registers[7]}"

    tests.append(("SLTI set less than immediate", test_slti))
    tests.append(("SRA shift right arithmetic", test_sra))
    tests.append(("SLL shift left", test_sll))
    tests.append(("SRL shift right", test_srl))
    tests.append(("XOR bitwise", test_xor))
    tests.append(("JMP unconditional", test_jmp))
    tests.append(("LW/SW memory", test_lw_sw))
    tests.append(("ALU sequence", test_alu_sequence))
    tests.append(("BEQ taken", test_beq_taken_skip))
    tests.append(("BNE loop to zero", test_bne_negative_loop))
    tests.append(("Max-steps guard", test_max_steps_guard))
    tests.append(("ADDI immediate", test_addi))

    print(f"[SELF-TEST] Running {len(tests)} Python simulator tests")
    passed = 0
    for name, fn in tests:
        try:
            fn()
            passed += 1
            print(f"  [PASS] {name}")
        except AssertionError as exc:
            msg = str(exc) if str(exc) else "assertion failed"
            print(f"  [FAIL] {name} -- {msg}")
    print(f"[SELF-TEST] Summary: {passed}/{len(tests)} passed")
    return 0 if passed == len(tests) else 1


def main():
    if len(sys.argv) >= 2 and sys.argv[1] == "--self-test":
        sys.exit(run_self_tests())

    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <hex_file> [--demo]")
        print(f"       {sys.argv[0]} --self-test")
        print(f"Example: {sys.argv[0]} program.hex --demo")
        sys.exit(1)
    
    hex_file = sys.argv[1]
    flags = set(sys.argv[2:])
    cpu = CPUSimulator()

    if not cpu.load_hex(hex_file):
        sys.exit(1)

    if "--demo" in flags:
        print("[MODE] Demo register seed enabled (R1=1..R7=7)")
        cpu.seed_demo_registers()

    if "--summary" in flags:
        cpu.set_trace(False)
        halted = cpu.run()
        print(f"\n=== Python Golden Model ===")
        print(f"Program: {hex_file}")
        print(f"Instructions executed: {cpu.instruction_count}")
        print(f"Final PC: {cpu.pc}")
        print(f"Registers: " + " ".join(f"R{i}={cpu.registers[i]}" for i in range(8)))
        # Show non-zero DMEM
        dmem_entries = [(a, cpu.dmem[a]) for a in range(256) if cpu.dmem[a] != 0]
        if dmem_entries:
            print(f"DMEM: " + "  ".join(f"[{a}]={v}" for a, v in dmem_entries))
        print(f"Status: {'HALT' if halted else 'TIMEOUT'}")
    else:
        cpu.run()


if __name__ == "__main__":
    main()

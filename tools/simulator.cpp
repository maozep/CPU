#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <iomanip>
#include <cstdint>
#include <string>
#include <cmath>
#include <functional>
#include <vector>

using namespace std;

class CPU {
private:
    // State
    uint8_t registers[8] = {0};      // R0-R7, 8-bit each
    uint16_t imem[256] = {0};        // Instruction Memory, 256 x 16-bit
    uint8_t dmem[256] = {0};         // Data Memory, 256 x 8-bit
    uint8_t pc = 0;                  // Program Counter, 8-bit
    bool halted = false;             // HALT flag
    bool trace_enabled = true;       // Verbose trace print flag
    
    // Statistics
    uint32_t instruction_count = 0;

public:
    void reset() {
        for (int i = 0; i < 8; i++) {
            registers[i] = 0;
        }
        for (int i = 0; i < 256; i++) {
            imem[i] = 0;
            dmem[i] = 0;
        }
        pc = 0;
        halted = false;
        instruction_count = 0;
    }

    void set_trace(bool enable) {
        trace_enabled = enable;
    }

    bool load_program(const vector<uint16_t>& words) {
        reset();
        size_t count = words.size();
        if (count > 256) {
            count = 256;
        }
        for (size_t i = 0; i < count; i++) {
            imem[i] = words[i];
        }
        return true;
    }

    void set_register(int idx, uint8_t value) {
        if (idx < 0 || idx >= 8) {
            return;
        }
        if (idx == 0) {
            return;
        }
        registers[idx] = value;
    }

    // Seed registers with a visible demo pattern without changing the
    // architectural reset behavior used by default.
    void seed_demo_registers() {
        for (int i = 1; i < 8; i++) {
            registers[i] = (uint8_t)i;
        }
    }

    // Helper: Extract bits [high:low] from a 16-bit value
    inline uint16_t extract_bits(uint16_t value, int high, int low) const {
        int width = high - low + 1;
        return (value >> low) & ((1 << width) - 1);
    }
    
    // Helper: Sign-extend a value from given width to 16-bit
    inline int16_t sign_extend(uint16_t value, int width) const {
        if (value & (1 << (width - 1))) {
            // Sign bit is set; extend with 1s
            return (int16_t)value | (0xFFFF << width);
        }
        return (int16_t)value;
    }
    
    // Load HEX file into instruction memory
    bool load_hex(const string& filename) {
        reset();

        ifstream file(filename);
        if (!file.is_open()) {
            cerr << "Error: Cannot open file " << filename << endl;
            return false;
        }
        
        string line;
        int address = 0;
        
        while (getline(file, line) && address < 256) {
            // Remove comments
            size_t comment_pos = line.find("//");
            if (comment_pos != string::npos) {
                line = line.substr(0, comment_pos);
            }
            
            // Trim whitespace
            line.erase(0, line.find_first_not_of(" \t\r\n"));
            line.erase(line.find_last_not_of(" \t\r\n") + 1);
            
            // Skip empty lines
            if (line.empty()) continue;
            
            // Parse hex value
            try {
                uint16_t value = (uint16_t)stoul(line, nullptr, 16);
                imem[address] = value;
                address++;
            } catch (...) {
                cerr << "Warning: Invalid hex value on line: " << line << endl;
            }
        }
        
        file.close();
        if (trace_enabled) {
            cout << "[LOADER] Loaded " << address << " instructions from " << filename << endl;
        }
        return true;
    }
    
    // Fetch instruction at current PC
    uint16_t fetch() const {
        return imem[pc];
    }
    
    // Decode and execute instruction
    void execute(uint16_t instr) {
        uint16_t opcode = extract_bits(instr, 15, 12);
        
           // Print instruction info before execution
           if (trace_enabled) {
              cout << "[PC=" << setfill('0') << setw(2) << hex << (int)pc << " | "
                  << "Instr=0x" << setfill('0') << setw(4) << hex << instr << "]" << dec << " ";
           }
        
        switch (opcode) {
            case 0x0:  // HALT
                execute_halt();
                break;
            case 0x1:  // ADD
                execute_alu(instr, '+');
                break;
            case 0x2:  // SUB
                execute_alu(instr, '-');
                break;
            case 0x3:  // AND
                execute_alu(instr, '&');
                break;
            case 0x4:  // OR
                execute_alu(instr, '|');
                break;
            case 0xB:  // XOR
                execute_alu(instr, '^');
                break;
            case 0xC:  // SLL
                execute_alu(instr, '<');
                break;
            case 0xD:  // SRL
                execute_alu(instr, '>');
                break;
            case 0xE:  // SRA
                execute_alu(instr, 'a');
                break;
            case 0x5:  // BEQ
                execute_branch(instr, true);
                break;
            case 0x6:  // BNE
                execute_branch(instr, false);
                break;
            case 0x7:  // ADDI
                execute_addi(instr);
                break;
            case 0x8:  // LW
                execute_lw(instr);
                break;
            case 0x9:  // SW
                execute_sw(instr);
                break;
            case 0xA:  // JMP
                execute_jmp(instr);
                break;
            default:
                if (trace_enabled) {
                    cout << "UNKNOWN OPCODE 0x" << hex << (int)opcode << dec << endl;
                }
                break;
        }
    }
    
    // Execute ADDI instruction: rd = rs1 + sign_extend(imm6)
    void execute_addi(uint16_t instr) {
        uint8_t rd  = (uint8_t)extract_bits(instr, 11, 9);
        uint8_t rs1 = (uint8_t)extract_bits(instr, 8, 6);
        uint16_t imm6_raw = extract_bits(instr, 5, 0);
        int16_t imm6 = sign_extend(imm6_raw, 6);
        uint8_t result = (uint8_t)(registers[rs1] + imm6);
        if (trace_enabled) {
            cout << "ADDI R" << (int)rd << " = R" << (int)rs1
                 << "(" << (int)registers[rs1] << ") + " << (int)imm6
                 << " = " << (int)result << endl;
        }
        registers[rd] = result;
        pc++;
    }

    // Execute ALU instruction (ADD, SUB, AND, OR, XOR)
    void execute_alu(uint16_t instr, char op) {
        uint8_t rd  = (uint8_t)extract_bits(instr, 11, 9);
        uint8_t rs1 = (uint8_t)extract_bits(instr, 8, 6);
        uint8_t rs2 = (uint8_t)extract_bits(instr, 5, 3);
        
        uint8_t result = 0;
        
        switch (op) {
            case '+':
                result = registers[rs1] + registers[rs2];
                if (trace_enabled) {
                    cout << "ADD R" << (int)rd << " = R" << (int)rs1 << "(" << (int)registers[rs1]
                         << ") + R" << (int)rs2 << "(" << (int)registers[rs2] << ") = " << (int)result;
                }
                break;
            case '-':
                result = registers[rs1] - registers[rs2];
                if (trace_enabled) {
                    cout << "SUB R" << (int)rd << " = R" << (int)rs1 << "(" << (int)registers[rs1]
                         << ") - R" << (int)rs2 << "(" << (int)registers[rs2] << ") = " << (int)result;
                }
                break;
            case '&':
                result = registers[rs1] & registers[rs2];
                if (trace_enabled) {
                    cout << "AND R" << (int)rd << " = R" << (int)rs1 << "(" << (int)registers[rs1]
                         << ") & R" << (int)rs2 << "(" << (int)registers[rs2] << ") = " << (int)result;
                }
                break;
            case '|':
                result = registers[rs1] | registers[rs2];
                if (trace_enabled) {
                    cout << "OR  R" << (int)rd << " = R" << (int)rs1 << "(" << (int)registers[rs1]
                         << ") | R" << (int)rs2 << "(" << (int)registers[rs2] << ") = " << (int)result;
                }
                break;
            case '^':
                result = registers[rs1] ^ registers[rs2];
                if (trace_enabled) {
                    cout << "XOR R" << (int)rd << " = R" << (int)rs1 << "(" << (int)registers[rs1]
                         << ") ^ R" << (int)rs2 << "(" << (int)registers[rs2] << ") = " << (int)result;
                }
                break;
            case '<': {
                uint8_t shift = registers[rs2] & 0x7;
                result = (uint8_t)(registers[rs1] << shift);
                if (trace_enabled) {
                    cout << "SLL R" << (int)rd << " = R" << (int)rs1 << "(" << (int)registers[rs1]
                         << ") << R" << (int)rs2 << "(" << (int)shift << ") = " << (int)result;
                }
                break;
            }
            case '>': {
                uint8_t shift = registers[rs2] & 0x7;
                result = (uint8_t)(registers[rs1] >> shift);
                if (trace_enabled) {
                    cout << "SRL R" << (int)rd << " = R" << (int)rs1 << "(" << (int)registers[rs1]
                         << ") >> R" << (int)rs2 << "(" << (int)shift << ") = " << (int)result;
                }
                break;
            }
            case 'a': {
                uint8_t shift = registers[rs2] & 0x7;
                int8_t signed_val = (int8_t)registers[rs1];
                result = (uint8_t)(signed_val >> shift);
                if (trace_enabled) {
                    cout << "SRA R" << (int)rd << " = R" << (int)rs1 << "(" << (int)registers[rs1]
                         << ") >>> R" << (int)rs2 << "(" << (int)shift << ") = " << (int)result;
                }
                break;
            }
        }
        
        registers[rd] = result;
        pc++;
        if (trace_enabled) {
            cout << endl;
        }
    }
    
    // Execute branch instruction (BEQ, BNE)
    void execute_branch(uint16_t instr, bool is_beq) {
        uint8_t rs1 = (uint8_t)extract_bits(instr, 11, 9);
        uint8_t rs2 = (uint8_t)extract_bits(instr, 8, 6);
        int8_t  offset_raw = (int8_t)extract_bits(instr, 5, 0);  // 6-bit signed
        
        // Sign-extend to 8-bit
        int16_t offset = sign_extend((uint16_t)offset_raw, 6);
        
        bool branch_taken = false;
        if (is_beq) {
            branch_taken = (registers[rs1] == registers[rs2]);
            if (trace_enabled) {
                cout << "BEQ R" << (int)rs1 << "(" << (int)registers[rs1] << ") == R"
                     << (int)rs2 << "(" << (int)registers[rs2] << ") ? ";
            }
        } else {
            branch_taken = (registers[rs1] != registers[rs2]);
            if (trace_enabled) {
                cout << "BNE R" << (int)rs1 << "(" << (int)registers[rs1] << ") != R"
                     << (int)rs2 << "(" << (int)registers[rs2] << ") ? ";
            }
        }
        
        uint8_t next_pc = pc + 1;  // Default: no branch
        
        if (branch_taken) {
            next_pc = (next_pc + offset) & 0xFF;  // 8-bit wrap
            if (trace_enabled) {
                cout << "YES -> PC = " << (int)(pc + 1) << " + " << (int)offset << " = " << (int)next_pc;
            }
        } else {
            if (trace_enabled) {
                cout << "NO -> PC = " << (int)next_pc;
            }
        }
        
        pc = next_pc;
        if (trace_enabled) {
            cout << endl;
        }
    }
    
    // Execute LW instruction: rd = DMEM[rs1 + sign_extend(imm6)]
    void execute_lw(uint16_t instr) {
        uint8_t rd  = (uint8_t)extract_bits(instr, 11, 9);
        uint8_t rs1 = (uint8_t)extract_bits(instr, 8, 6);
        uint16_t imm6_raw = extract_bits(instr, 5, 0);
        int16_t imm6 = sign_extend(imm6_raw, 6);
        uint8_t addr = (uint8_t)(registers[rs1] + imm6);
        uint8_t result = dmem[addr];
        if (trace_enabled) {
            cout << "LW  R" << (int)rd << " = DMEM[R" << (int)rs1
                 << "(" << (int)registers[rs1] << ") + " << (int)imm6
                 << "] = DMEM[" << (int)addr << "] = " << (int)result << endl;
        }
        registers[rd] = result;
        pc++;
    }

    // Execute SW instruction: DMEM[rs1 + sign_extend(imm6)] = rs2
    void execute_sw(uint16_t instr) {
        uint8_t rs2 = (uint8_t)extract_bits(instr, 11, 9);  // data source
        uint8_t rs1 = (uint8_t)extract_bits(instr, 8, 6);   // base address
        uint16_t imm6_raw = extract_bits(instr, 5, 0);
        int16_t imm6 = sign_extend(imm6_raw, 6);
        uint8_t addr = (uint8_t)(registers[rs1] + imm6);
        uint8_t data = registers[rs2];
        if (trace_enabled) {
            cout << "SW  DMEM[R" << (int)rs1 << "(" << (int)registers[rs1]
                 << ") + " << (int)imm6 << "] = DMEM[" << (int)addr
                 << "] = R" << (int)rs2 << "(" << (int)data << ")" << endl;
        }
        dmem[addr] = data;
        pc++;
    }

    // Execute JMP instruction: unconditional relative jump
    void execute_jmp(uint16_t instr) {
        uint16_t offset_raw = extract_bits(instr, 5, 0);
        int16_t offset = sign_extend(offset_raw, 6);
        uint8_t next_pc = (uint8_t)((pc + 1 + offset) & 0xFF);
        if (trace_enabled) {
            cout << "JMP offset=" << (int)offset << " -> PC = "
                 << (int)(pc + 1) << " + " << (int)offset << " = " << (int)next_pc << endl;
        }
        pc = next_pc;
    }

    // Execute HALT instruction
    void execute_halt() {
        if (trace_enabled) {
            cout << "HALT -- Execution stopped" << endl;
        }
        halted = true;
    }
    
    // Print current register file state
    void print_registers() const {
        cout << "  Registers: ";
        for (int i = 0; i < 8; i++) {
            cout << "R" << i << "=" << setfill('0') << setw(2) << hex << (int)registers[i] << " ";
        }
        cout << dec << endl;
    }
    
    // Run the complete fetch-decode-execute loop
    bool run(uint32_t max_steps = 10000) {
        if (trace_enabled) {
            cout << "\n=== Starting CPU Simulation ===" << endl;
            cout << "Initial PC: " << (int)pc << endl << endl;
        }
        
        while (!halted && pc < 256 && instruction_count < max_steps) {
            uint16_t instr = fetch();
            
            if (trace_enabled) {
                print_registers();
            }
            execute(instr);
            
            instruction_count++;
        }

        bool completed_by_halt = halted;
        if (!completed_by_halt && trace_enabled) {
            cout << "[WARN] Stopped due to max_steps=" << max_steps << endl;
        }
        
        if (trace_enabled) {
            cout << "\n=== Simulation Complete ===" << endl;
            cout << "Total instructions executed: " << instruction_count << endl;
            cout << "Final PC: " << (int)pc << endl;
            cout << "Final Registers: ";
            for (int i = 0; i < 8; i++) {
                cout << "R" << i << "=" << setfill('0') << setw(2) << hex << (int)registers[i] << " ";
            }
            cout << dec << endl;
        }

        return completed_by_halt;
    }
    
    // Get register value (for testing/verification)
    uint8_t get_register(int idx) const {
        if (idx >= 0 && idx < 8) return registers[idx];
        return 0;
    }
    
    // Get data memory value
    uint8_t get_dmem(int addr) const {
        if (addr >= 0 && addr < 256) return dmem[addr];
        return 0;
    }

    // Get PC
    uint8_t get_pc() const {
        return pc;
    }

    bool is_halted() const {
        return halted;
    }

    uint32_t get_instruction_count() const {
        return instruction_count;
    }
};

static uint16_t encode_rtype(uint8_t opcode, uint8_t rd, uint8_t rs1, uint8_t rs2) {
    return (uint16_t)(((opcode & 0xF) << 12) | ((rd & 0x7) << 9) | ((rs1 & 0x7) << 6) | ((rs2 & 0x7) << 3));
}

static uint16_t encode_branch(uint8_t opcode, uint8_t rs1, uint8_t rs2, int8_t offset6) {
    return (uint16_t)(((opcode & 0xF) << 12) | ((rs1 & 0x7) << 9) | ((rs2 & 0x7) << 6) | ((uint8_t)offset6 & 0x3F));
}

static uint16_t encode_itype(uint8_t opcode, uint8_t rd, uint8_t rs1, int8_t imm6) {
    return (uint16_t)(((opcode & 0xF) << 12) | ((rd & 0x7) << 9) | ((rs1 & 0x7) << 6) | ((uint8_t)imm6 & 0x3F));
}

static bool expect_eq_u8(const string& name, uint8_t got, uint8_t expected, string& err) {
    if (got != expected) {
        stringstream ss;
        ss << name << " expected=" << (int)expected << " got=" << (int)got;
        err = ss.str();
        return false;
    }
    return true;
}

static bool expect_true(const string& name, bool cond, string& err) {
    if (!cond) {
        err = name;
        return false;
    }
    return true;
}

static bool test_alu_sequence(string& err) {
    CPU cpu;
    cpu.set_trace(false);
    cpu.load_program({
        encode_rtype(0x1, 3, 1, 2), // R3 = R1 + R2
        encode_rtype(0x2, 4, 3, 2), // R4 = R3 - R2
        encode_rtype(0x3, 5, 3, 2), // R5 = R3 & R2
        encode_rtype(0x4, 6, 4, 2), // R6 = R4 | R2
        0x0000
    });
    cpu.set_register(1, 5);
    cpu.set_register(2, 2);

    bool halted = cpu.run();
    if (!expect_true("Program should HALT", halted, err)) return false;
    if (!expect_eq_u8("R3", cpu.get_register(3), 7, err)) return false;
    if (!expect_eq_u8("R4", cpu.get_register(4), 5, err)) return false;
    if (!expect_eq_u8("R5", cpu.get_register(5), 2, err)) return false;
    if (!expect_eq_u8("R6", cpu.get_register(6), 7, err)) return false;
    return true;
}

static bool test_beq_taken(string& err) {
    CPU cpu;
    cpu.set_trace(false);
    cpu.load_program({
        encode_branch(0x5, 1, 2, 1), // if equal, skip next instruction
        encode_rtype(0x1, 3, 1, 1),
        encode_rtype(0x1, 4, 1, 2),
        0x0000
    });
    cpu.set_register(1, 9);
    cpu.set_register(2, 9);

    bool halted = cpu.run();
    if (!expect_true("Program should HALT", halted, err)) return false;
    if (!expect_eq_u8("R3 should stay unchanged (skipped)", cpu.get_register(3), 0, err)) return false;
    if (!expect_eq_u8("R4", cpu.get_register(4), 18, err)) return false;
    return true;
}

static bool test_bne_loop_to_zero(string& err) {
    CPU cpu;
    cpu.set_trace(false);
    cpu.load_program({
        encode_rtype(0x2, 1, 1, 7),   // R1 = R1 - R7
        encode_branch(0x6, 1, 0, -2), // if R1 != 0, jump back to SUB
        0x0000
    });
    cpu.set_register(1, 3);
    cpu.set_register(7, 1);

    bool halted = cpu.run();
    if (!expect_true("Program should HALT", halted, err)) return false;
    if (!expect_eq_u8("R1 should reach zero", cpu.get_register(1), 0, err)) return false;
    if (!expect_eq_u8("PC at HALT", cpu.get_pc(), 2, err)) return false;
    return true;
}

static bool test_max_steps_guard(string& err) {
    CPU cpu;
    cpu.set_trace(false);
    cpu.load_program({
        encode_branch(0x6, 1, 0, -1), // self-loop while R1 != 0
        0x0000
    });
    cpu.set_register(1, 1);

    bool halted = cpu.run(20);
    if (!expect_true("Program should not HALT before max_steps", !halted, err)) return false;
    if (!expect_eq_u8("PC should stay in loop", cpu.get_pc(), 0, err)) return false;
    if (cpu.get_instruction_count() != 20) {
        stringstream ss;
        ss << "instruction_count expected=20 got=" << cpu.get_instruction_count();
        err = ss.str();
        return false;
    }
    return true;
}

static bool test_addi(string& err) {
    CPU cpu;
    cpu.set_trace(false);
    cpu.load_program({
        encode_itype(0x7, 2, 1, 10),   // R2 = R1 + 10  (5+10=15)
        encode_itype(0x7, 3, 1, -3),   // R3 = R1 + (-3) (5-3=2)
        encode_itype(0x7, 4, 0,  7),   // R4 = R0 + 7   (0+7=7)
        encode_itype(0x7, 5, 2, 31),   // R5 = R2 + 31  (15+31=46) -- max positive imm
        encode_itype(0x7, 6, 2, -32),  // R6 = R2 + (-32) (15-32=239 wrap)
        0x0000
    });
    cpu.set_register(1, 5);
    bool halted = cpu.run();
    if (!expect_true("Program should HALT", halted, err)) return false;
    if (!expect_eq_u8("R2 (5+10)", cpu.get_register(2), 15,  err)) return false;
    if (!expect_eq_u8("R3 (5-3)",  cpu.get_register(3), 2,   err)) return false;
    if (!expect_eq_u8("R4 (0+7)",  cpu.get_register(4), 7,   err)) return false;
    if (!expect_eq_u8("R5 (15+31)",cpu.get_register(5), 46,  err)) return false;
    if (!expect_eq_u8("R6 (15-32 wrap)", cpu.get_register(6), 239, err)) return false;
    return true;
}

static bool test_lw_sw(string& err) {
    CPU cpu;
    cpu.set_trace(false);
    cpu.load_program({
        encode_itype(0x7, 1, 0, 25),   // R1 = 25
        encode_itype(0x7, 2, 0, 10),   // R2 = 10
        encode_itype(0x9, 1, 0, 0),    // SW R1 -> DMEM[0] = 25
        encode_itype(0x9, 2, 0, 5),    // SW R2 -> DMEM[5] = 10
        encode_itype(0x8, 3, 0, 0),    // LW R3 = DMEM[0] = 25
        encode_itype(0x8, 4, 0, 5),    // LW R4 = DMEM[5] = 10
        encode_itype(0x8, 5, 0, 1),    // LW R5 = DMEM[1] = 0 (unwritten)
        0x0000
    });
    bool halted = cpu.run();
    if (!expect_true("Program should HALT", halted, err)) return false;
    if (!expect_eq_u8("R3 (LW addr 0)", cpu.get_register(3), 25, err)) return false;
    if (!expect_eq_u8("R4 (LW addr 5)", cpu.get_register(4), 10, err)) return false;
    if (!expect_eq_u8("R5 (LW unwritten)", cpu.get_register(5), 0, err)) return false;
    if (!expect_eq_u8("DMEM[0]", cpu.get_dmem(0), 25, err)) return false;
    if (!expect_eq_u8("DMEM[5]", cpu.get_dmem(5), 10, err)) return false;
    return true;
}

static bool test_jmp(string& err) {
    CPU cpu;
    cpu.set_trace(false);
    cpu.load_program({
        encode_itype(0x7, 1, 0, 5),    // PC=0: ADDI R1, R0, 5
        encode_branch(0xA, 0, 0, 1),   // PC=1: JMP +1 (skip PC=2)
        encode_itype(0x7, 4, 0, 20),   // PC=2: ADDI R4, R0, 20 (SKIPPED)
        encode_branch(0xA, 0, 0, 2),   // PC=3: JMP +2 (skip to PC=6)
        encode_itype(0x7, 5, 0, 20),   // PC=4: ADDI R5, R0, 20 (via backward)
        0x0000,                          // PC=5: HALT
        encode_itype(0x7, 3, 0, 10),   // PC=6: ADDI R3, R0, 10
        encode_branch(0xA, 0, 0, -4),  // PC=7: JMP -4 (to PC=4)
    });
    bool halted = cpu.run();
    if (!expect_true("Program should HALT", halted, err)) return false;
    if (!expect_eq_u8("R1", cpu.get_register(1), 5, err)) return false;
    if (!expect_eq_u8("R3", cpu.get_register(3), 10, err)) return false;
    if (!expect_eq_u8("R4 (skipped)", cpu.get_register(4), 0, err)) return false;
    if (!expect_eq_u8("R5 (backward jump)", cpu.get_register(5), 20, err)) return false;
    return true;
}

static bool test_sll(string& err) {
    CPU cpu;
    cpu.set_trace(false);
    cpu.load_program({
        encode_rtype(0xC, 3, 1, 2), // R3 = R1 << R2
        encode_rtype(0xC, 4, 1, 3), // R4 = R1 << R3
        encode_rtype(0xC, 5, 2, 6), // R5 = R2 << R6
        encode_rtype(0xC, 6, 1, 0), // R6 = R1 << R0
        0x0000
    });
    cpu.set_register(1, 1);
    cpu.set_register(2, 0xA5);
    cpu.set_register(3, 8);
    cpu.set_register(6, 4);
    bool halted = cpu.run();
    if (!expect_true("Program should HALT", halted, err)) return false;
    if (!expect_eq_u8("R3 (1<<5)", cpu.get_register(3), 32, err)) return false;
    if (!expect_eq_u8("R4 (1<<0)", cpu.get_register(4), 1, err)) return false;
    if (!expect_eq_u8("R5 (0xA5<<4)", cpu.get_register(5), 0x50, err)) return false;
    if (!expect_eq_u8("R6 (1<<0)", cpu.get_register(6), 1, err)) return false;
    return true;
}

static bool test_srl(string& err) {
    CPU cpu;
    cpu.set_trace(false);
    cpu.load_program({
        encode_rtype(0xD, 3, 1, 2), // R3 = R1 >> R2
        encode_rtype(0xD, 4, 1, 3), // R4 = R1 >> R3
        encode_rtype(0xD, 5, 1, 0), // R5 = R1 >> R0
        0x0000
    });
    cpu.set_register(1, 0x80);
    cpu.set_register(2, 1);
    cpu.set_register(3, 4);
    bool halted = cpu.run();
    if (!expect_true("Program should HALT", halted, err)) return false;
    if (!expect_eq_u8("R3 (0x80>>1)", cpu.get_register(3), 0x40, err)) return false;
    if (!expect_eq_u8("R4 (0x80>>0)", cpu.get_register(4), 0x80, err)) return false;
    if (!expect_eq_u8("R5 (0x80>>0)", cpu.get_register(5), 0x80, err)) return false;
    return true;
}

static bool test_sra(string& err) {
    CPU cpu;
    cpu.set_trace(false);
    cpu.load_program({
        encode_rtype(0xE, 3, 1, 2), // R3 = R1 >>> R2 (0x80>>>1 = 0xC0)
        encode_rtype(0xE, 4, 1, 3), // R4 = R1 >>> R3 (0x80>>>(0xC0&7=0) = 0x80)
        encode_rtype(0xE, 5, 1, 6), // R5 = R1 >>> R6 (0x80>>>7 = 0xFF)
        encode_rtype(0xE, 6, 7, 2), // R6 = R7 >>> R2 (0x7F>>>1 = 0x3F)
        encode_rtype(0xE, 7, 1, 0), // R7 = R1 >>> R0 (0x80>>>0 = 0x80)
        0x0000
    });
    cpu.set_register(1, 0x80);
    cpu.set_register(2, 1);
    cpu.set_register(6, 7);
    cpu.set_register(7, 0x7F);
    bool halted = cpu.run();
    if (!expect_true("Program should HALT", halted, err)) return false;
    if (!expect_eq_u8("R3 (0x80>>>1)", cpu.get_register(3), 0xC0, err)) return false;
    if (!expect_eq_u8("R4 (0x80>>>0)", cpu.get_register(4), 0x80, err)) return false;
    if (!expect_eq_u8("R5 (0x80>>>7)", cpu.get_register(5), 0xFF, err)) return false;
    if (!expect_eq_u8("R6 (0x7F>>>1)", cpu.get_register(6), 0x3F, err)) return false;
    if (!expect_eq_u8("R7 (0x80>>>0)", cpu.get_register(7), 0x80, err)) return false;
    return true;
}

static bool test_xor(string& err) {
    CPU cpu;
    cpu.set_trace(false);
    cpu.load_program({
        encode_rtype(0xB, 3, 1, 2), // R3 = R1 ^ R2
        encode_rtype(0xB, 4, 1, 1), // R4 = R1 ^ R1 (should be 0)
        encode_rtype(0xB, 5, 1, 0), // R5 = R1 ^ R0 (should be R1)
        0x0000
    });
    cpu.set_register(1, 0xA5);
    cpu.set_register(2, 0x5A);
    bool halted = cpu.run();
    if (!expect_true("Program should HALT", halted, err)) return false;
    if (!expect_eq_u8("R3 (0xA5^0x5A)", cpu.get_register(3), 0xFF, err)) return false;
    if (!expect_eq_u8("R4 (0xA5^0xA5)", cpu.get_register(4), 0x00, err)) return false;
    if (!expect_eq_u8("R5 (0xA5^0x00)", cpu.get_register(5), 0xA5, err)) return false;
    return true;
}

static int run_self_tests() {
    vector<pair<string, function<bool(string&)>>> tests = {
        {"LW/SW memory", test_lw_sw},
        {"ALU sequence", test_alu_sequence},
        {"BEQ taken", test_beq_taken},
        {"BNE loop to zero", test_bne_loop_to_zero},
        {"Max-steps guard", test_max_steps_guard},
        {"ADDI immediate", test_addi},
        {"JMP unconditional", test_jmp},
        {"XOR bitwise", test_xor},
        {"SLL shift left", test_sll},
        {"SRL shift right", test_srl},
        {"SRA shift right arithmetic", test_sra}
    };

    int passed = 0;
    cout << "[SELF-TEST] Running " << tests.size() << " simulator tests" << endl;

    for (size_t i = 0; i < tests.size(); i++) {
        string err;
        bool ok = tests[i].second(err);
        if (ok) {
            passed++;
            cout << "  [PASS] " << tests[i].first << endl;
        } else {
            cout << "  [FAIL] " << tests[i].first << " -- " << err << endl;
        }
    }

    cout << "[SELF-TEST] Summary: " << passed << "/" << tests.size() << " passed" << endl;
    return (passed == (int)tests.size()) ? 0 : 1;
}

int main(int argc, char* argv[]) {
    if (argc >= 2 && string(argv[1]) == "--self-test") {
        return run_self_tests();
    }

    if (argc < 2) {
        cerr << "Usage: " << argv[0] << " <hex_file> [--demo]" << endl;
        cerr << "       " << argv[0] << " --self-test" << endl;
        cerr << "Example: " << argv[0] << " program.hex --demo" << endl;
        return 1;
    }
    
    CPU cpu;
    
    // Load HEX file
    if (!cpu.load_hex(argv[1])) {
        return 1;
    }

    if (argc >= 3 && string(argv[2]) == "--demo") {
        cout << "[MODE] Demo register seed enabled (R1=1..R7=7)" << endl;
        cpu.seed_demo_registers();
    }
    
    // Run simulation
    cpu.run();
    
    return 0;
}

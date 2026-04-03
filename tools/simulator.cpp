#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <iomanip>
#include <cstdint>
#include <string>
#include <cmath>

using namespace std;

class CPU {
private:
    // State
    uint8_t registers[8] = {0};      // R0-R7, 8-bit each
    uint16_t imem[256] = {0};        // Instruction Memory, 256 x 16-bit
    uint8_t pc = 0;                  // Program Counter, 8-bit
    bool halted = false;             // HALT flag
    
    // Statistics
    uint32_t instruction_count = 0;

public:
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
        cout << "[LOADER] Loaded " << address << " instructions from " << filename << endl;
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
        cout << "[PC=" << setfill('0') << setw(2) << hex << (int)pc << " | "
             << "Instr=0x" << setfill('0') << setw(4) << hex << instr << "]" << dec << " ";
        
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
            case 0x5:  // BEQ
                execute_branch(instr, true);
                break;
            case 0x6:  // BNE
                execute_branch(instr, false);
                break;
            default:
                cout << "UNKNOWN OPCODE 0x" << hex << (int)opcode << dec << endl;
                break;
        }
    }
    
    // Execute ALU instruction (ADD, SUB, AND, OR)
    void execute_alu(uint16_t instr, char op) {
        uint8_t rd  = (uint8_t)extract_bits(instr, 11, 9);
        uint8_t rs1 = (uint8_t)extract_bits(instr, 8, 6);
        uint8_t rs2 = (uint8_t)extract_bits(instr, 5, 3);
        
        uint8_t result = 0;
        
        switch (op) {
            case '+':
                result = registers[rs1] + registers[rs2];
                cout << "ADD R" << (int)rd << " = R" << (int)rs1 << "(" << (int)registers[rs1]
                     << ") + R" << (int)rs2 << "(" << (int)registers[rs2] << ") = " << (int)result;
                break;
            case '-':
                result = registers[rs1] - registers[rs2];
                cout << "SUB R" << (int)rd << " = R" << (int)rs1 << "(" << (int)registers[rs1]
                     << ") - R" << (int)rs2 << "(" << (int)registers[rs2] << ") = " << (int)result;
                break;
            case '&':
                result = registers[rs1] & registers[rs2];
                cout << "AND R" << (int)rd << " = R" << (int)rs1 << "(" << (int)registers[rs1]
                     << ") & R" << (int)rs2 << "(" << (int)registers[rs2] << ") = " << (int)result;
                break;
            case '|':
                result = registers[rs1] | registers[rs2];
                cout << "OR  R" << (int)rd << " = R" << (int)rs1 << "(" << (int)registers[rs1]
                     << ") | R" << (int)rs2 << "(" << (int)registers[rs2] << ") = " << (int)result;
                break;
        }
        
        registers[rd] = result;
        pc++;
        cout << endl;
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
            cout << "BEQ R" << (int)rs1 << "(" << (int)registers[rs1] << ") == R"
                 << (int)rs2 << "(" << (int)registers[rs2] << ") ? ";
        } else {
            branch_taken = (registers[rs1] != registers[rs2]);
            cout << "BNE R" << (int)rs1 << "(" << (int)registers[rs1] << ") != R"
                 << (int)rs2 << "(" << (int)registers[rs2] << ") ? ";
        }
        
        uint8_t next_pc = pc + 1;  // Default: no branch
        
        if (branch_taken) {
            next_pc = (next_pc + offset) & 0xFF;  // 8-bit wrap
            cout << "YES -> PC = " << (int)(pc + 1) << " + " << (int)offset << " = " << (int)next_pc;
        } else {
            cout << "NO -> PC = " << (int)next_pc;
        }
        
        pc = next_pc;
        cout << endl;
    }
    
    // Execute HALT instruction
    void execute_halt() {
        cout << "HALT -- Execution stopped" << endl;
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
    void run() {
        cout << "\n=== Starting CPU Simulation ===" << endl;
        cout << "Initial PC: " << (int)pc << endl << endl;
        
        while (!halted && pc < 256) {
            uint16_t instr = fetch();
            
            print_registers();
            execute(instr);
            
            instruction_count++;
        }
        
        cout << "\n=== Simulation Complete ===" << endl;
        cout << "Total instructions executed: " << instruction_count << endl;
        cout << "Final PC: " << (int)pc << endl;
        cout << "Final Registers: ";
        for (int i = 0; i < 8; i++) {
            cout << "R" << i << "=" << setfill('0') << setw(2) << hex << (int)registers[i] << " ";
        }
        cout << dec << endl;
    }
    
    // Get register value (for testing/verification)
    uint8_t get_register(int idx) const {
        if (idx >= 0 && idx < 8) return registers[idx];
        return 0;
    }
    
    // Get PC
    uint8_t get_pc() const {
        return pc;
    }
};

int main(int argc, char* argv[]) {
    if (argc < 2) {
        cerr << "Usage: " << argv[0] << " <hex_file>" << endl;
        cerr << "Example: " << argv[0] << " program.hex" << endl;
        return 1;
    }
    
    CPU cpu;
    
    // Load HEX file
    if (!cpu.load_hex(argv[1])) {
        return 1;
    }
    
    // Run simulation
    cpu.run();
    
    return 0;
}

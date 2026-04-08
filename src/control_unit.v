// control_unit.v -- Instruction decode and control signal generation
// Decodes a 16-bit instruction into register addresses and ALU control.

module control_unit (
    input  wire [15:0] instr,
    output reg  [3:0]  opcode,
    output reg  [2:0]  rd_addr,
    output reg  [2:0]  rs1_addr,
    output reg  [2:0]  rs2_addr,
    output reg         reg_write,
    output reg  [2:0]  alu_op,
    output reg         use_imm,
    output reg         mem_read,
    output reg         mem_write,
    output reg         mem_to_reg,
    output wire        is_branch,
    output wire        is_bne,
    output wire        is_jump,
    output wire        is_halt
);

    parameter BNE = 4'h6;

    assign is_branch = (opcode == 4'h5);
    assign is_bne    = (opcode == BNE);
    assign is_jump   = (opcode == 4'hA);
    assign is_halt   = (opcode == 4'h0);

    always @* begin
        // Default decode (R-type):
        // [15:12] opcode | [11:9] rd | [8:6] rs1 | [5:3] rs2 | [2:0] imm
        opcode   = instr[15:12];
        rd_addr  = instr[11:9];
        rs1_addr = instr[8:6];
        rs2_addr = instr[5:3];

        // Defaults (no writeback, no memory access)
        reg_write  = 1'b0;
        alu_op     = 3'b000;
        use_imm    = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;

        case (opcode)
            4'h0: begin // HALT
                reg_write = 1'b0;
                alu_op    = 3'b000;
            end
            4'h1: begin // ADD
                reg_write = 1'b1;
                alu_op    = 3'b000;
            end
            4'h2: begin // SUB
                reg_write = 1'b1;
                alu_op    = 3'b001;
            end
            4'h3: begin // AND
                reg_write = 1'b1;
                alu_op    = 3'b010;
            end
            4'h4: begin // OR
                reg_write = 1'b1;
                alu_op    = 3'b011;
            end
            4'hB: begin // XOR
                reg_write = 1'b1;
                alu_op    = 3'b100;
            end
            4'hC: begin // SLL
                reg_write = 1'b1;
                alu_op    = 3'b101;
            end
            4'hD: begin // SRL
                reg_write = 1'b1;
                alu_op    = 3'b110;
            end
            4'hE: begin // SRA
                reg_write = 1'b1;
                alu_op    = 3'b111;
            end
            4'h7: begin // ADDI: rd = rs1 + sign_extend(instr[5:0])
                // Field layout: [15:12] opcode | [11:9] rd | [8:6] rs1 | [5:0] imm6
                rd_addr   = instr[11:9];
                rs1_addr  = instr[8:6];
                reg_write = 1'b1;
                alu_op    = 3'b000; // ADD
                use_imm   = 1'b1;
            end
            4'h5: begin // BEQ
                // BEQ mapping (strict 16-bit):
                // instr[11:9] = rs1, instr[8:6] = rs2, instr[5:0] = branch offset
                rs1_addr = instr[11:9];
                rs2_addr = instr[8:6];
                reg_write = 1'b0;
                alu_op    = 3'b001; // SUB for equality compare via zero flag
            end
            BNE: begin // BNE (same field layout as BEQ)
                rs1_addr = instr[11:9];
                rs2_addr = instr[8:6];
                reg_write = 1'b0;
                alu_op    = 3'b001; // SUB for compare via zero flag
            end
            4'h8: begin // LW: rd = DMEM[rs1 + sign_extend(imm6)]
                // Format: [15:12] opcode | [11:9] rd | [8:6] rs1 | [5:0] imm6
                rd_addr    = instr[11:9];
                rs1_addr   = instr[8:6];
                reg_write  = 1'b1;
                alu_op     = 3'b000; // ADD for address calculation
                use_imm    = 1'b1;
                mem_read   = 1'b1;
                mem_to_reg = 1'b1;
            end
            4'h9: begin // SW: DMEM[rs1 + sign_extend(imm6)] = rd
                // Format: [15:12] opcode | [11:9] rs2(data) | [8:6] rs1(base) | [5:0] imm6
                rs1_addr  = instr[8:6];
                rs2_addr  = instr[11:9]; // data source register
                reg_write = 1'b0;
                alu_op    = 3'b000; // ADD for address calculation
                use_imm   = 1'b1;
                mem_write = 1'b1;
            end
            4'hA: begin // JMP: unconditional relative jump
                reg_write = 1'b0;
            end
            default: begin
                reg_write = 1'b0;
                alu_op    = 3'b000;
            end
        endcase
    end

endmodule


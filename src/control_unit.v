// control_unit.v -- Instruction decode and control signal generation
// Decodes a 16-bit instruction into register addresses and ALU control.

module control_unit (
    input  wire [15:0] instr,
    output reg  [3:0]  opcode,
    output reg  [2:0]  rd_addr,
    output reg  [2:0]  rs1_addr,
    output reg  [2:0]  rs2_addr,
    output reg         reg_write,
    output reg  [2:0]  alu_op
);

    always @* begin
        // Instruction field extraction
        opcode   = instr[15:12];
        // Field layout aligned to root `program.hex` encoding:
        // rd=instr[10:8], rs1=instr[6:4], rs2=instr[2:0]
        rd_addr  = instr[10:8];
        rs1_addr = instr[6:4];
        rs2_addr = instr[2:0];

        // Defaults (no writeback)
        reg_write = 1'b0;
        alu_op    = 3'b000;

        case (opcode)
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
            default: begin
                reg_write = 1'b0;
                alu_op    = 3'b000;
            end
        endcase
    end

endmodule


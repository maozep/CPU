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
        rd_addr  = instr[11:9];
        rs1_addr = instr[8:6];
        rs2_addr = instr[5:3];

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


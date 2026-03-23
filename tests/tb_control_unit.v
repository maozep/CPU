`timescale 1ns/1ps

module tb_control_unit;

    reg  [15:0] instr;
    wire [3:0]  opcode;
    wire [2:0]  rd_addr;
    wire [2:0]  rs1_addr;
    wire [2:0]  rs2_addr;
    wire         reg_write;
    wire [2:0]  alu_op;

    control_unit dut (
        .instr     (instr),
        .opcode    (opcode),
        .rd_addr   (rd_addr),
        .rs1_addr  (rs1_addr),
        .rs2_addr  (rs2_addr),
        .reg_write (reg_write),
        .alu_op    (alu_op)
    );

    integer errors;

    initial begin
        $dumpfile("control_unit_waves.vcd");
        $dumpvars(0, tb_control_unit);

        errors = 0;

        // ADD scenario: opcode=4'h1 => ADD => reg_write=1, alu_op=3'b000
        // Field layout aligned to root `program.hex`:
        // rd=in;str[10:8], rs1=instr[6:4], rs2=instr[2:0]
        // Choose rd=3, rs1=1, rs2=2 => instr = 0x1312
        instr = 16'h1312;
        #1;
        $display("ADD  instr=0x%04h opcode=0x%1h rd=%0d rs1=%0d rs2=%0d reg_write=%b alu_op=0x%1h",
            instr, opcode, rd_addr, rs1_addr, rs2_addr, reg_write, alu_op);
        if (reg_write !== 1'b1 || alu_op !== 3'b000) begin
            $display("FAIL: ADD control mismatch");
            errors = errors + 1;
        end

        // SUB scenario: opcode=4'h2 => SUB => reg_write=1, alu_op=3'b001
        // Example instruction aligned to root `program.hex` encoding.
        // Choose an instruction with opcode=2 => instr = 0x2541
        instr = 16'h2541;
        #1;
        $display("SUB  instr=0x%04h opcode=0x%1h rd=%0d rs1=%0d rs2=%0d reg_write=%b alu_op=0x%1h",
            instr, opcode, rd_addr, rs1_addr, rs2_addr, reg_write, alu_op);
        if (reg_write !== 1'b1 || alu_op !== 3'b001) begin
            $display("FAIL: SUB control mismatch");
            errors = errors + 1;
        end

        // Unknown scenario: opcode not in {1,2,3,4} => reg_write=0, alu_op=3'b000
        // Keep any rd/rs1/rs2 fields; only opcode matters for reg_write/alu_op.
        // opcode=9 => instr = 0x9298
        instr = 16'h9298;
        #1;
        $display("UNK  instr=0x%04h opcode=0x%1h rd=%0d rs1=%0d rs2=%0d reg_write=%b alu_op=0x%1h",
            instr, opcode, rd_addr, rs1_addr, rs2_addr, reg_write, alu_op);
        if (reg_write !== 1'b0 || alu_op !== 3'b000) begin
            $display("FAIL: UNKNOWN control mismatch");
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("PASS: control_unit tests passed.");
        end else begin
            $display("DONE: control_unit tests, errors=%0d.", errors);
        end

        $finish;
    end

endmodule


`timescale 1ns/1ps

module tb_control_unit;

    reg  [15:0] instr;
    wire [3:0]  opcode;
    wire [2:0]  rd_addr;
    wire [2:0]  rs1_addr;
    wire [2:0]  rs2_addr;
    wire         reg_write;
    wire [2:0]  alu_op;
    wire         use_imm;
    wire         mem_read;
    wire         mem_write;
    wire         mem_to_reg;
    wire         is_branch;
    wire         is_bne;
    wire         is_halt;

    control_unit dut (
        .instr     (instr),
        .opcode    (opcode),
        .rd_addr   (rd_addr),
        .rs1_addr  (rs1_addr),
        .rs2_addr  (rs2_addr),
        .reg_write (reg_write),
        .alu_op    (alu_op),
        .use_imm   (use_imm),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .mem_to_reg(mem_to_reg),
        .is_branch (is_branch),
        .is_bne    (is_bne),
        .is_halt   (is_halt)
    );

    integer errors;

    initial begin
        $dumpfile("control_unit_waves.vcd");
        $dumpvars(0, tb_control_unit);

        errors = 0;

        // HALT scenario: opcode=0 => is_halt=1, no writeback.
        instr = 16'h0000;
        #1;
        $display("HALT instr=0x%04h opcode=0x%1h reg_write=%b alu_op=0x%1h is_halt=%b",
            instr, opcode, reg_write, alu_op, is_halt);
        if (is_halt !== 1'b1 || reg_write !== 1'b0) begin
            $display("FAIL: HALT control mismatch");
            errors = errors + 1;
        end

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

        // BNE scenario: opcode=6 => is_bne=1, is_branch=0, reg_write=0, alu_op=SUB (compare)
        // Same branch-style field map as BEQ: rs1=instr[11:9], rs2=instr[8:6], offset in [5:0]
        instr = 16'h6280;
        #1;
        $display("BNE  instr=0x%04h opcode=0x%1h rs1=%0d rs2=%0d reg_write=%b alu_op=0x%1h is_branch=%b is_bne=%b",
            instr, opcode, rs1_addr, rs2_addr, reg_write, alu_op, is_branch, is_bne);
        if (is_bne !== 1'b1 || is_branch !== 1'b0 || reg_write !== 1'b0 || alu_op !== 3'b001) begin
            $display("FAIL: BNE control mismatch");
            errors = errors + 1;
        end

        // LW scenario: opcode=8 => reg_write=1, use_imm=1, mem_read=1, mem_to_reg=1
        // LW R3, R1, 5 => opcode=0x8, rd=3, rs1=1, imm6=5
        // instr = 1000 011 001 000101 = 0x8645
        instr = 16'h8645;
        #1;
        $display("LW   instr=0x%04h opcode=0x%1h rd=%0d rs1=%0d reg_write=%b alu_op=0x%1h use_imm=%b mem_read=%b mem_to_reg=%b",
            instr, opcode, rd_addr, rs1_addr, reg_write, alu_op, use_imm, mem_read, mem_to_reg);
        if (reg_write !== 1'b1 || use_imm !== 1'b1 || mem_read !== 1'b1 || mem_to_reg !== 1'b1 || alu_op !== 3'b000) begin
            $display("FAIL: LW control mismatch");
            errors = errors + 1;
        end
        if (rd_addr !== 3'd3 || rs1_addr !== 3'd1) begin
            $display("FAIL: LW register address mismatch rd=%0d rs1=%0d", rd_addr, rs1_addr);
            errors = errors + 1;
        end

        // SW scenario: opcode=9 => reg_write=0, use_imm=1, mem_write=1, mem_to_reg=0
        // SW R2, R1, 0 => opcode=0x9, [11:9]=R2(data)=010, [8:6]=R1(base)=001, imm=0
        // instr = 1001 010 001 000000 = 0x9440
        instr = 16'h9440;
        #1;
        $display("SW   instr=0x%04h opcode=0x%1h rs1=%0d rs2=%0d reg_write=%b alu_op=0x%1h use_imm=%b mem_write=%b",
            instr, opcode, rs1_addr, rs2_addr, reg_write, alu_op, use_imm, mem_write);
        if (reg_write !== 1'b0 || use_imm !== 1'b1 || mem_write !== 1'b1 || alu_op !== 3'b000) begin
            $display("FAIL: SW control mismatch");
            errors = errors + 1;
        end
        if (rs1_addr !== 3'd1 || rs2_addr !== 3'd2) begin
            $display("FAIL: SW register address mismatch rs1=%0d rs2=%0d (expected rs1=1 rs2=2)", rs1_addr, rs2_addr);
            errors = errors + 1;
        end

        // XOR scenario: opcode=0xB => reg_write=1, alu_op=3'b100
        // XOR R3, R1, R2 => opcode=0xB, rd=3, rs1=1, rs2=2
        // instr = 1011 011 001 010 000 = 0xB650
        instr = 16'hB650;
        #1;
        $display("XOR  instr=0x%04h opcode=0x%1h rd=%0d rs1=%0d rs2=%0d reg_write=%b alu_op=0x%1h",
            instr, opcode, rd_addr, rs1_addr, rs2_addr, reg_write, alu_op);
        if (reg_write !== 1'b1 || alu_op !== 3'b100) begin
            $display("FAIL: XOR control mismatch");
            errors = errors + 1;
        end

        // SLL scenario: opcode=0xC => reg_write=1, alu_op=3'b101
        // SLL R3, R1, R2 => instr = 1100 011 001 010 000 = 0xC650
        instr = 16'hC650;
        #1;
        $display("SLL  instr=0x%04h opcode=0x%1h rd=%0d rs1=%0d rs2=%0d reg_write=%b alu_op=0x%1h",
            instr, opcode, rd_addr, rs1_addr, rs2_addr, reg_write, alu_op);
        if (reg_write !== 1'b1 || alu_op !== 3'b101) begin
            $display("FAIL: SLL control mismatch");
            errors = errors + 1;
        end

        // SRL scenario: opcode=0xD => reg_write=1, alu_op=3'b110
        // SRL R3, R1, R2 => instr = 1101 011 001 010 000 = 0xD650
        instr = 16'hD650;
        #1;
        $display("SRL  instr=0x%04h opcode=0x%1h rd=%0d rs1=%0d rs2=%0d reg_write=%b alu_op=0x%1h",
            instr, opcode, rd_addr, rs1_addr, rs2_addr, reg_write, alu_op);
        if (reg_write !== 1'b1 || alu_op !== 3'b110) begin
            $display("FAIL: SRL control mismatch");
            errors = errors + 1;
        end

        // SRA scenario: opcode=0xE => reg_write=1, alu_op=3'b111
        // SRA R3, R1, R2 => instr = 1110 011 001 010 000 = 0xE650
        instr = 16'hE650;
        #1;
        $display("SRA  instr=0x%04h opcode=0x%1h rd=%0d rs1=%0d rs2=%0d reg_write=%b alu_op=0x%1h",
            instr, opcode, rd_addr, rs1_addr, rs2_addr, reg_write, alu_op);
        if (reg_write !== 1'b1 || alu_op !== 3'b111) begin
            $display("FAIL: SRA control mismatch");
            errors = errors + 1;
        end

        // SLTI scenario: opcode=0xF => reg_write=1, use_imm=1
        // SLTI R3, R1, 5 => opcode=0xF, rd=3, rs1=1, imm6=5
        // instr = 1111 011 001 000101 = 0xF645
        instr = 16'hF645;
        #1;
        $display("SLTI instr=0x%04h opcode=0x%1h rd=%0d rs1=%0d reg_write=%b use_imm=%b",
            instr, opcode, rd_addr, rs1_addr, reg_write, use_imm);
        if (reg_write !== 1'b1 || use_imm !== 1'b1) begin
            $display("FAIL: SLTI control mismatch");
            errors = errors + 1;
        end
        if (rd_addr !== 3'd3 || rs1_addr !== 3'd1) begin
            $display("FAIL: SLTI register address mismatch rd=%0d rs1=%0d", rd_addr, rs1_addr);
            errors = errors + 1;
        end

        // No more unknown scenario -- all opcodes 0x0..0xF are now used

        // ADDI scenario: opcode=7 => reg_write=1, alu_op=ADD, use_imm=1
        // ADDI R3, R1, -3 => opcode=0x7, rd=3, rs1=1, imm6=0x3D (-3 in 6-bit)
        // instr = 0111 011 001 111101 = 0x76_7D => 0x767D
        instr = 16'h767D;
        #1;
        $display("ADDI instr=0x%04h opcode=0x%1h rd=%0d rs1=%0d reg_write=%b alu_op=0x%1h use_imm=%b",
            instr, opcode, rd_addr, rs1_addr, reg_write, alu_op, use_imm);
        if (reg_write !== 1'b1 || alu_op !== 3'b000 || use_imm !== 1'b1) begin
            $display("FAIL: ADDI control mismatch");
            errors = errors + 1;
        end
        if (rd_addr !== 3'b011 || rs1_addr !== 3'b001) begin
            $display("FAIL: ADDI register address mismatch rd=%0d rs1=%0d", rd_addr, rs1_addr);
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


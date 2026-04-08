// tb_sra.v -- ISA Validation Testbench for the SRA instruction
// Tests: SRA rd, rs1, rs2  =>  rd = rs1 >>> rs2[2:0] (arithmetic, sign-extending)
//
// Test cases (R1=0x80 [negative], R2=1, R6=7, R7=0x7F [positive]):
//   1. SRA R3, R1, R2  -> 0x80 >>> 1 = 0xC0 (sign bit fills)
//   2. SRA R4, R1, R3  -> 0x80 >>> (R3&7=0) = 0x80
//   3. SRA R5, R1, R6  -> 0x80 >>> 7 = 0xFF (all 1s from sign)
//   4. SRA R6, R7, R2  -> 0x7F >>> 1 = 0x3F (positive, zero fills)
//   5. SRA R7, R1, R0  -> 0x80 >>> 0 = 0x80 (no shift)

`timescale 1ns / 1ps

module tb_sra;

    reg         clk;
    reg         rst;
    wire [15:0] current_instruction;
    wire [31:0] cycle_count;

    integer tb_cc;
    integer errors;

    cpu uut (
        .clk                 (clk),
        .rst                 (rst),
        .current_instruction (current_instruction),
        .cycle_count  (cycle_count)
    );

    initial clk = 1'b0;
    always  #5 clk = ~clk;

    initial begin
        $dumpfile("sra_waves.vcd");
        $dumpvars(0, tb_sra);
    end

    initial begin
        errors = 0;
        rst = 1'b1;

        $readmemh("tests/isa_tests/program_sra_test.hex", uut.imem_inst.rom);
        $display("[TB] Loaded program_sra_test.hex");

        uut.regfile_inst.regs[1] = 8'h80;  // negative (bit 7 set)
        uut.regfile_inst.regs[2] = 8'h01;
        uut.regfile_inst.regs[6] = 8'h07;
        uut.regfile_inst.regs[7] = 8'h7F;  // positive (bit 7 clear)
        $display("[TB] Injected: R1=0x%02h  R2=0x%02h  R6=0x%02h  R7=0x%02h",
                 uut.regfile_inst.regs[1], uut.regfile_inst.regs[2],
                 uut.regfile_inst.regs[6], uut.regfile_inst.regs[7]);

        @(posedge clk); #1;
        @(posedge clk); #1;
        rst = 1'b0;
        $display("[TB] Reset released at time %0t ns.", $time);

        tb_cc = 0;
        while (current_instruction !== 16'h0000 && tb_cc < 30) begin
            @(posedge clk);
            tb_cc = tb_cc + 1;
        end
        @(posedge clk); #1;

        if (current_instruction === 16'h0000)
            $display("[TB] HALT detected at PC=%0d after %0d cycles (hw cycles: %0d).",
                     uut.pc_to_imem, tb_cc, cycle_count);
        else
            $display("[TB] WARNING: timed out without HALT. PC=%0d", uut.pc_to_imem);

        $display("------------------------------------------------");
        $display("  SRA Validation Results (R1=0x80, R7=0x7F)");
        $display("------------------------------------------------");
        $display("  R3 (SRA 0x80>>>1, sign fill)    Result: %0d  (expected 192)", uut.regfile_inst.regs[3]);
        $display("  R4 (SRA 0x80>>>0, no shift)     Result: %0d  (expected 128)", uut.regfile_inst.regs[4]);
        $display("  R5 (SRA 0x80>>>7, max shift)    Result: %0d  (expected 255)", uut.regfile_inst.regs[5]);
        $display("  R6 (SRA 0x7F>>>1, positive)     Result: %0d  (expected 63)",  uut.regfile_inst.regs[6]);
        $display("  R7 (SRA 0x80>>>0, no shift)     Result: %0d  (expected 128)", uut.regfile_inst.regs[7]);
        $display("------------------------------------------------");

        if (uut.regfile_inst.regs[3] !== 8'd192) begin $display("  FAIL: R3"); errors=errors+1; end
        if (uut.regfile_inst.regs[4] !== 8'd128) begin $display("  FAIL: R4"); errors=errors+1; end
        if (uut.regfile_inst.regs[5] !== 8'd255) begin $display("  FAIL: R5"); errors=errors+1; end
        if (uut.regfile_inst.regs[6] !== 8'd63)  begin $display("  FAIL: R6"); errors=errors+1; end
        if (uut.regfile_inst.regs[7] !== 8'd128) begin $display("  FAIL: R7"); errors=errors+1; end

        if (errors == 0)
            $display("  RESULT: PASS -- all SRA operations verified.");
        else
            $display("  RESULT: FAIL -- %0d check(s) failed.", errors);
        $display("------------------------------------------------");

        $finish;
    end

    always @(negedge clk) begin
        if (!rst)
            $display("  t=%0t | PC=%0d | Instr=0x%04h | R3=%0d R4=%0d R5=%0d R6=%0d R7=%0d",
                     $time, uut.pc_to_imem, current_instruction,
                     uut.regfile_inst.regs[3], uut.regfile_inst.regs[4],
                     uut.regfile_inst.regs[5], uut.regfile_inst.regs[6],
                     uut.regfile_inst.regs[7]);
    end

endmodule

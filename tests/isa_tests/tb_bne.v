// tb_bne.v -- ISA Validation Testbench for the BNE instruction
// Tests: BNE rs1, rs2, offset  =>  branch if rs1 != rs2
//
// Test cases:
//   1. BNE R1,R2,+1  -> taken (not equal), R4 skipped
//   2. BNE R1,R3,+1  -> not taken (equal), R5 executes
//   3. BNE R1,R1,+2  -> not taken (self-compare, always equal), R6 executes
//   4. BNE R0,R1,+1  -> taken (zero-reg vs non-zero), R7 skipped
//   Expected: R4=0, R5=25, R6=20, R7=0

`timescale 1ns / 1ps

module tb_bne;

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
        $dumpfile("bne_waves.vcd");
        $dumpvars(0, tb_bne);
    end

    initial begin
        errors = 0;
        rst = 1'b1;

        $readmemh("tests/isa_tests/program_bne_test.hex", uut.imem_inst.rom);
        $display("[TB] Loaded program_bne_test.hex");

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
        $display("  BNE Validation Results");
        $display("------------------------------------------------");
        $display("  R4 (skipped by BNE taken)        Result: %0d  (expected 0)",  uut.regfile_inst.regs[4]);
        $display("  R5 (BNE not taken, executes)     Result: %0d  (expected 25)", uut.regfile_inst.regs[5]);
        $display("  R6 (self-compare not taken)      Result: %0d  (expected 20)", uut.regfile_inst.regs[6]);
        $display("  R7 (skipped by R0!=R1)           Result: %0d  (expected 0)",  uut.regfile_inst.regs[7]);
        $display("------------------------------------------------");

        if (uut.regfile_inst.regs[4] !== 8'd0)  begin $display("  FAIL: R4 (should be skipped)"); errors=errors+1; end
        if (uut.regfile_inst.regs[5] !== 8'd25) begin $display("  FAIL: R5"); errors=errors+1; end
        if (uut.regfile_inst.regs[6] !== 8'd20) begin $display("  FAIL: R6 (self-compare should not branch)"); errors=errors+1; end
        if (uut.regfile_inst.regs[7] !== 8'd0)  begin $display("  FAIL: R7 (should be skipped by R0!=R1)"); errors=errors+1; end

        if (errors == 0)
            $display("  RESULT: PASS -- all BNE operations verified.");
        else
            $display("  RESULT: FAIL -- %0d check(s) failed.", errors);
        $display("------------------------------------------------");

        $finish;
    end

    always @(negedge clk) begin
        if (!rst)
            $display("  t=%0t | PC=%0d | Instr=0x%04h | R4=%0d R5=%0d R6=%0d R7=%0d",
                     $time, uut.pc_to_imem, current_instruction,
                     uut.regfile_inst.regs[4], uut.regfile_inst.regs[5],
                     uut.regfile_inst.regs[6], uut.regfile_inst.regs[7]);
    end

endmodule

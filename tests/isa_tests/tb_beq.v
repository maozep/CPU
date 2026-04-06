// tb_beq.v -- ISA Validation Testbench for the BEQ instruction
// Tests: BEQ rs1, rs2, offset  =>  branch if rs1 == rs2
//
// Test cases:
//   1. BEQ R1,R2,+1  -> taken (equal), R4 skipped
//   2. BEQ R1,R3,+1  -> not taken (not equal), R5 executes
//   3. BEQ R0,R0,+2  -> taken (zero-reg self-compare, offset +2), R6 skipped
//   Expected: R4=0, R5=25, R6=0, R7=7

`timescale 1ns / 1ps

module tb_beq;

    reg         clk;
    reg         rst;
    wire [15:0] current_instruction;

    integer cycle_count;
    integer errors;

    cpu uut (
        .clk                 (clk),
        .rst                 (rst),
        .current_instruction (current_instruction)
    );

    initial clk = 1'b0;
    always  #5 clk = ~clk;

    initial begin
        $dumpfile("beq_waves.vcd");
        $dumpvars(0, tb_beq);
    end

    initial begin
        errors = 0;
        rst = 1'b1;

        $readmemh("tests/isa_tests/program_beq_test.hex", uut.imem_inst.rom);
        $display("[TB] Loaded program_beq_test.hex");

        @(posedge clk); #1;
        @(posedge clk); #1;
        rst = 1'b0;
        $display("[TB] Reset released at time %0t ns.", $time);

        cycle_count = 0;
        while (current_instruction !== 16'h0000 && cycle_count < 30) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end
        @(posedge clk); #1;

        if (current_instruction === 16'h0000)
            $display("[TB] HALT detected at PC=%0d after %0d cycles.",
                     uut.pc_to_imem, cycle_count);
        else
            $display("[TB] WARNING: timed out without HALT. PC=%0d", uut.pc_to_imem);

        $display("------------------------------------------------");
        $display("  BEQ Validation Results");
        $display("------------------------------------------------");
        $display("  R4 (skipped by BEQ taken)       Result: %0d  (expected 0)",  uut.regfile_inst.regs[4]);
        $display("  R5 (BEQ not taken, executes)    Result: %0d  (expected 25)", uut.regfile_inst.regs[5]);
        $display("  R6 (skipped by R0==R0, off +2)  Result: %0d  (expected 0)",  uut.regfile_inst.regs[6]);
        $display("  R7 (after R0==R0 branch lands)  Result: %0d  (expected 7)",  uut.regfile_inst.regs[7]);
        $display("------------------------------------------------");

        if (uut.regfile_inst.regs[4] !== 8'd0)  begin $display("  FAIL: R4 (should be skipped)"); errors=errors+1; end
        if (uut.regfile_inst.regs[5] !== 8'd25) begin $display("  FAIL: R5"); errors=errors+1; end
        if (uut.regfile_inst.regs[6] !== 8'd0)  begin $display("  FAIL: R6 (should be skipped by R0==R0)"); errors=errors+1; end
        if (uut.regfile_inst.regs[7] !== 8'd7)  begin $display("  FAIL: R7"); errors=errors+1; end

        if (errors == 0)
            $display("  RESULT: PASS -- all BEQ operations verified.");
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

// tb_bne.v -- ISA Validation Testbench for the BNE instruction
// Tests: BNE rs1, rs2, offset  =>  branch if rs1 != rs2
//
// Test plan:
//   1. Load R1=5, R2=10 (not equal), R3=5 (equal) via ADDI
//   2. BNE R1,R2,+1  -> should TAKE branch (R1!=R2), skipping R4 write
//   3. BNE R1,R3,+1  -> should NOT branch (R1==R3), R5 write executes
//   Expected: R4=0 (skipped), R5=25 (executed)

`timescale 1ns / 1ps

module tb_bne;

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
        $display("  BNE Validation Results");
        $display("------------------------------------------------");
        $display("  R1 (ADDI R0+5)         Result: %0d  (expected 5)",  uut.regfile_inst.regs[1]);
        $display("  R2 (ADDI R0+10)        Result: %0d  (expected 10)", uut.regfile_inst.regs[2]);
        $display("  R3 (ADDI R0+5)         Result: %0d  (expected 5)",  uut.regfile_inst.regs[3]);
        $display("  R4 (skipped by BNE)    Result: %0d  (expected 0)",  uut.regfile_inst.regs[4]);
        $display("  R5 (not skipped)       Result: %0d  (expected 25)", uut.regfile_inst.regs[5]);
        $display("------------------------------------------------");

        if (uut.regfile_inst.regs[1] !== 8'd5)  begin $display("  FAIL: R1"); errors=errors+1; end
        if (uut.regfile_inst.regs[2] !== 8'd10) begin $display("  FAIL: R2"); errors=errors+1; end
        if (uut.regfile_inst.regs[3] !== 8'd5)  begin $display("  FAIL: R3"); errors=errors+1; end
        if (uut.regfile_inst.regs[4] !== 8'd0)  begin $display("  FAIL: R4 (should have been skipped)"); errors=errors+1; end
        if (uut.regfile_inst.regs[5] !== 8'd25) begin $display("  FAIL: R5"); errors=errors+1; end

        if (errors == 0)
            $display("  RESULT: PASS -- all BNE operations verified.");
        else
            $display("  RESULT: FAIL -- %0d check(s) failed.", errors);
        $display("------------------------------------------------");

        $finish;
    end

    always @(negedge clk) begin
        if (!rst)
            $display("  t=%0t | PC=%0d | Instr=0x%04h | R1=%0d R2=%0d R3=%0d R4=%0d R5=%0d",
                     $time, uut.pc_to_imem, current_instruction,
                     uut.regfile_inst.regs[1], uut.regfile_inst.regs[2],
                     uut.regfile_inst.regs[3], uut.regfile_inst.regs[4],
                     uut.regfile_inst.regs[5]);
    end

endmodule

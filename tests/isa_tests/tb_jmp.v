// tb_jmp.v -- ISA Validation Testbench for the JMP instruction
// Tests: JMP offset  =>  unconditional relative jump (PC = PC + 1 + sign_extend(offset))
//
// Test cases:
//   1. JMP +1  -> skip one instruction (R4 stays 0)
//   2. JMP +2  -> skip two instructions, land at PC=6
//   3. JMP -4  -> backward jump from PC=7 to PC=4, then HALT at PC=5
//   Expected: R1=5, R3=10, R4=0 (skipped), R5=20 (via backward jump)

`timescale 1ns / 1ps

module tb_jmp;

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
        $dumpfile("jmp_waves.vcd");
        $dumpvars(0, tb_jmp);
    end

    initial begin
        errors = 0;
        rst = 1'b1;

        $readmemh("tests/isa_tests/program_jmp_test.hex", uut.imem_inst.rom);
        $display("[TB] Loaded program_jmp_test.hex");

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
        $display("  JMP Validation Results");
        $display("------------------------------------------------");
        $display("  R1 (ADDI before JMP)            Result: %0d  (expected 5)",  uut.regfile_inst.regs[1]);
        $display("  R3 (ADDI after JMP +2 lands)    Result: %0d  (expected 10)", uut.regfile_inst.regs[3]);
        $display("  R4 (skipped by JMP +1)          Result: %0d  (expected 0)",  uut.regfile_inst.regs[4]);
        $display("  R5 (reached via backward JMP)   Result: %0d  (expected 20)", uut.regfile_inst.regs[5]);
        $display("------------------------------------------------");

        if (uut.regfile_inst.regs[1] !== 8'd5)  begin $display("  FAIL: R1"); errors=errors+1; end
        if (uut.regfile_inst.regs[3] !== 8'd10) begin $display("  FAIL: R3"); errors=errors+1; end
        if (uut.regfile_inst.regs[4] !== 8'd0)  begin $display("  FAIL: R4 (should be skipped)"); errors=errors+1; end
        if (uut.regfile_inst.regs[5] !== 8'd20) begin $display("  FAIL: R5 (backward jump target)"); errors=errors+1; end

        if (errors == 0)
            $display("  RESULT: PASS -- all JMP operations verified.");
        else
            $display("  RESULT: FAIL -- %0d check(s) failed.", errors);
        $display("------------------------------------------------");

        $finish;
    end

    always @(negedge clk) begin
        if (!rst)
            $display("  t=%0t | PC=%0d | Instr=0x%04h | R1=%0d R3=%0d R4=%0d R5=%0d",
                     $time, uut.pc_to_imem, current_instruction,
                     uut.regfile_inst.regs[1], uut.regfile_inst.regs[3],
                     uut.regfile_inst.regs[4], uut.regfile_inst.regs[5]);
    end

endmodule

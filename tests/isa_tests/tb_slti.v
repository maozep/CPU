// tb_slti.v -- ISA Validation Testbench for the SLTI instruction
// Tests: SLTI rd, rs1, imm6  =>  rd = (rs1 < sign_extend(imm6)) ? 1 : 0  (signed)
//
// Test cases (R1=5, R2=0x80 i.e. -128 signed):
//   1. SLTI R3, R1, 10   -> 5 < 10 = 1 (true)
//   2. SLTI R4, R1, 5    -> 5 < 5 = 0 (equal, not less)
//   3. SLTI R5, R1, 3    -> 5 < 3 = 0 (false)
//   4. SLTI R6, R2, 0    -> -128 < 0 = 1 (true, signed)
//   5. SLTI R7, R1, -1   -> 5 < -1 = 0 (false, signed)

`timescale 1ns / 1ps

module tb_slti;

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
        $dumpfile("slti_waves.vcd");
        $dumpvars(0, tb_slti);
    end

    initial begin
        errors = 0;
        rst = 1'b1;

        $readmemh("tests/isa_tests/program_slti_test.hex", uut.imem_inst.rom);
        $display("[TB] Loaded program_slti_test.hex");

        uut.regfile_inst.regs[1] = 8'd5;
        uut.regfile_inst.regs[2] = 8'h80;  // -128 signed
        $display("[TB] Injected: R1=%0d  R2=0x%02h (signed: -128)",
                 uut.regfile_inst.regs[1], uut.regfile_inst.regs[2]);

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
        $display("  SLTI Validation Results (R1=5, R2=-128)");
        $display("------------------------------------------------");
        $display("  R3 (5 < 10, true)      Result: %0d  (expected 1)", uut.regfile_inst.regs[3]);
        $display("  R4 (5 < 5, equal)      Result: %0d  (expected 0)", uut.regfile_inst.regs[4]);
        $display("  R5 (5 < 3, false)      Result: %0d  (expected 0)", uut.regfile_inst.regs[5]);
        $display("  R6 (-128 < 0, signed)  Result: %0d  (expected 1)", uut.regfile_inst.regs[6]);
        $display("  R7 (5 < -1, signed)    Result: %0d  (expected 0)", uut.regfile_inst.regs[7]);
        $display("------------------------------------------------");

        if (uut.regfile_inst.regs[3] !== 8'd1) begin $display("  FAIL: R3"); errors=errors+1; end
        if (uut.regfile_inst.regs[4] !== 8'd0) begin $display("  FAIL: R4"); errors=errors+1; end
        if (uut.regfile_inst.regs[5] !== 8'd0) begin $display("  FAIL: R5"); errors=errors+1; end
        if (uut.regfile_inst.regs[6] !== 8'd1) begin $display("  FAIL: R6"); errors=errors+1; end
        if (uut.regfile_inst.regs[7] !== 8'd0) begin $display("  FAIL: R7"); errors=errors+1; end

        if (errors == 0)
            $display("  RESULT: PASS -- all SLTI operations verified.");
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

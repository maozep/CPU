// tb_xor.v -- ISA Validation Testbench for the XOR instruction
// Tests: XOR rd, rs1, rs2  =>  rd = rs1 ^ rs2
//
// Test cases (R1=0xA5, R2=0x5A):
//   1. XOR R3, R1, R2  -> complementary bits -> 0xFF
//   2. XOR R4, R1, R1  -> self-XOR -> 0x00
//   3. XOR R5, R1, R0  -> XOR with zero -> identity (0xA5)
//   4. XOR R6, R2, R2  -> self-XOR -> 0x00
//   5. XOR R7, R0, R0  -> zero XOR zero -> 0x00

`timescale 1ns / 1ps

module tb_xor;

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
        $dumpfile("xor_waves.vcd");
        $dumpvars(0, tb_xor);
    end

    initial begin
        errors = 0;
        rst = 1'b1;

        $readmemh("tests/isa_tests/program_xor_test.hex", uut.imem_inst.rom);
        $display("[TB] Loaded program_xor_test.hex");

        // Inject test patterns
        uut.regfile_inst.regs[1] = 8'hA5;  // 10100101
        uut.regfile_inst.regs[2] = 8'h5A;  // 01011010
        $display("[TB] Injected: R1=0x%02h  R2=0x%02h",
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
        $display("  XOR Validation Results (R1=0xA5, R2=0x5A)");
        $display("------------------------------------------------");
        $display("  R3 (XOR R1^R2, complementary)   Result: %0d  (expected 255)", uut.regfile_inst.regs[3]);
        $display("  R4 (XOR R1^R1, self-xor)        Result: %0d  (expected 0)",   uut.regfile_inst.regs[4]);
        $display("  R5 (XOR R1^R0, identity)         Result: %0d  (expected 165)", uut.regfile_inst.regs[5]);
        $display("  R6 (XOR R2^R2, self-xor)        Result: %0d  (expected 0)",   uut.regfile_inst.regs[6]);
        $display("  R7 (XOR R0^R0, zero)            Result: %0d  (expected 0)",   uut.regfile_inst.regs[7]);
        $display("------------------------------------------------");

        if (uut.regfile_inst.regs[3] !== 8'd255) begin $display("  FAIL: R3"); errors=errors+1; end
        if (uut.regfile_inst.regs[4] !== 8'd0)   begin $display("  FAIL: R4"); errors=errors+1; end
        if (uut.regfile_inst.regs[5] !== 8'd165) begin $display("  FAIL: R5"); errors=errors+1; end
        if (uut.regfile_inst.regs[6] !== 8'd0)   begin $display("  FAIL: R6"); errors=errors+1; end
        if (uut.regfile_inst.regs[7] !== 8'd0)   begin $display("  FAIL: R7"); errors=errors+1; end

        if (errors == 0)
            $display("  RESULT: PASS -- all XOR operations verified.");
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

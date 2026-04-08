// tb_sll.v -- ISA Validation Testbench for the SLL instruction
// Tests: SLL rd, rs1, rs2  =>  rd = rs1 << rs2[2:0]
//
// Test cases (R1=0xA5, R2=1, R6=7):
//   1. SLL R3, R1, R2  -> 0xA5 << 1 = 0x4A
//   2. SLL R4, R1, R3  -> 0xA5 << (R3&7) = 0xA5 << 2 = 0x94
//   3. SLL R5, R1, R0  -> 0xA5 << 0 = 0xA5 (identity)
//   4. SLL R6, R1, R6  -> 0xA5 << 7 = 0x80
//   5. SLL R7, R0, R2  -> 0x00 << 1 = 0x00 (zero source)

`timescale 1ns / 1ps

module tb_sll;

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
        $dumpfile("sll_waves.vcd");
        $dumpvars(0, tb_sll);
    end

    initial begin
        errors = 0;
        rst = 1'b1;

        $readmemh("tests/isa_tests/program_sll_test.hex", uut.imem_inst.rom);
        $display("[TB] Loaded program_sll_test.hex");

        uut.regfile_inst.regs[1] = 8'hA5;
        uut.regfile_inst.regs[2] = 8'h01;
        uut.regfile_inst.regs[6] = 8'h07;
        $display("[TB] Injected: R1=0x%02h  R2=0x%02h  R6=0x%02h",
                 uut.regfile_inst.regs[1], uut.regfile_inst.regs[2], uut.regfile_inst.regs[6]);

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
        $display("  SLL Validation Results (R1=0xA5, R2=1, R6=7)");
        $display("------------------------------------------------");
        $display("  R3 (SLL R1<<R2, shift 1)   Result: %0d  (expected 74)",  uut.regfile_inst.regs[3]);
        $display("  R4 (SLL R1<<R3, shift 2)   Result: %0d  (expected 148)", uut.regfile_inst.regs[4]);
        $display("  R5 (SLL R1<<R0, shift 0)   Result: %0d  (expected 165)", uut.regfile_inst.regs[5]);
        $display("  R6 (SLL R1<<R6, shift 7)   Result: %0d  (expected 128)", uut.regfile_inst.regs[6]);
        $display("  R7 (SLL R0<<R2, zero src)  Result: %0d  (expected 0)",   uut.regfile_inst.regs[7]);
        $display("------------------------------------------------");

        // R3 = 0xA5 << 1 = 0x4A = 74
        if (uut.regfile_inst.regs[3] !== 8'd74)  begin $display("  FAIL: R3"); errors=errors+1; end
        // R4 = 0xA5 << (R3&7) = 0xA5 << 2 = 0x94 = 148
        if (uut.regfile_inst.regs[4] !== 8'd148) begin $display("  FAIL: R4"); errors=errors+1; end
        // R5 = 0xA5 << 0 = 0xA5 = 165
        if (uut.regfile_inst.regs[5] !== 8'd165) begin $display("  FAIL: R5"); errors=errors+1; end
        // R6 = 0xA5 << 7 = 0x80 = 128
        if (uut.regfile_inst.regs[6] !== 8'd128) begin $display("  FAIL: R6"); errors=errors+1; end
        // R7 = 0 << 1 = 0
        if (uut.regfile_inst.regs[7] !== 8'd0)   begin $display("  FAIL: R7"); errors=errors+1; end

        if (errors == 0)
            $display("  RESULT: PASS -- all SLL operations verified.");
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

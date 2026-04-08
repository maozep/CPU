// tb_srl.v -- ISA Validation Testbench for the SRL instruction
// Tests: SRL rd, rs1, rs2  =>  rd = rs1 >> rs2[2:0] (logical)
//
// Test cases (R1=0x80, R2=1, R6=7):
//   1. SRL R3, R1, R2  -> 0x80 >> 1 = 0x40
//   2. SRL R4, R1, R3  -> 0x80 >> (R3&7) = 0x80 >> 0 = 0x80
//   3. SRL R5, R1, R0  -> 0x80 >> 0 = 0x80 (identity)
//   4. SRL R6, R1, R6  -> 0x80 >> 7 = 0x01
//   5. SRL R7, R0, R2  -> 0x00 >> 1 = 0x00 (zero source)

`timescale 1ns / 1ps

module tb_srl;

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
        $dumpfile("srl_waves.vcd");
        $dumpvars(0, tb_srl);
    end

    initial begin
        errors = 0;
        rst = 1'b1;

        $readmemh("tests/isa_tests/program_srl_test.hex", uut.imem_inst.rom);
        $display("[TB] Loaded program_srl_test.hex");

        uut.regfile_inst.regs[1] = 8'h80;
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
        $display("  SRL Validation Results (R1=0x80, R2=1, R6=7)");
        $display("------------------------------------------------");
        $display("  R3 (SRL R1>>R2, shift 1)   Result: %0d  (expected 64)",  uut.regfile_inst.regs[3]);
        $display("  R4 (SRL R1>>R3, shift 0)   Result: %0d  (expected 128)", uut.regfile_inst.regs[4]);
        $display("  R5 (SRL R1>>R0, shift 0)   Result: %0d  (expected 128)", uut.regfile_inst.regs[5]);
        $display("  R6 (SRL R1>>R6, shift 7)   Result: %0d  (expected 1)",   uut.regfile_inst.regs[6]);
        $display("  R7 (SRL R0>>R2, zero src)  Result: %0d  (expected 0)",   uut.regfile_inst.regs[7]);
        $display("------------------------------------------------");

        // R3 = 0x80 >> 1 = 0x40 = 64
        if (uut.regfile_inst.regs[3] !== 8'd64)  begin $display("  FAIL: R3"); errors=errors+1; end
        // R4 = 0x80 >> (0x40&7) = 0x80 >> 0 = 0x80 = 128
        if (uut.regfile_inst.regs[4] !== 8'd128) begin $display("  FAIL: R4"); errors=errors+1; end
        // R5 = 0x80 >> 0 = 0x80 = 128
        if (uut.regfile_inst.regs[5] !== 8'd128) begin $display("  FAIL: R5"); errors=errors+1; end
        // R6 = 0x80 >> 7 = 0x01 = 1
        if (uut.regfile_inst.regs[6] !== 8'd1)   begin $display("  FAIL: R6"); errors=errors+1; end
        // R7 = 0 >> 1 = 0
        if (uut.regfile_inst.regs[7] !== 8'd0)   begin $display("  FAIL: R7"); errors=errors+1; end

        if (errors == 0)
            $display("  RESULT: PASS -- all SRL operations verified.");
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

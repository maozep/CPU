// tb_lw.v -- ISA Validation Testbench for the LW instruction
// Tests: LW rd, rs1, imm6  =>  rd = DMEM[rs1 + sign_extend(imm6)]
//
// Data memory is pre-injected by testbench (no dependency on SW).
// Test cases:
//   1. LW from addr 0 (injected 0xAA)
//   2. LW from addr 5 with immediate offset (injected 0x55)
//   3. LW from addr 31 with max positive offset (injected 0xBB)
//   4. LW with register base + negative offset (-5) -> DMEM[10-5]=DMEM[5]
//   5. LW from unwritten address -> 0

`timescale 1ns / 1ps

module tb_lw;

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
        $dumpfile("lw_waves.vcd");
        $dumpvars(0, tb_lw);
    end

    initial begin
        errors = 0;
        rst = 1'b1;

        $readmemh("tests/isa_tests/program_lw_test.hex", uut.imem_inst.rom);
        $display("[TB] Loaded program_lw_test.hex");

        // Inject data into data memory (independent of SW)
        uut.dmem_inst.ram[0]  = 8'hAA;
        uut.dmem_inst.ram[5]  = 8'h55;
        uut.dmem_inst.ram[31] = 8'hBB;
        $display("[TB] Injected DMEM: [0]=0xAA [5]=0x55 [31]=0xBB");

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
        $display("  LW Validation Results");
        $display("------------------------------------------------");
        $display("  R1 (LW addr 0)          Result: %0d (0x%02h)  (expected 170 / 0xAA)", uut.regfile_inst.regs[1], uut.regfile_inst.regs[1]);
        $display("  R2 (LW addr 5)          Result: %0d (0x%02h)  (expected 85 / 0x55)",  uut.regfile_inst.regs[2], uut.regfile_inst.regs[2]);
        $display("  R3 (LW addr 31)         Result: %0d (0x%02h)  (expected 187 / 0xBB)", uut.regfile_inst.regs[3], uut.regfile_inst.regs[3]);
        $display("  R4 (ADDI base=10)       Result: %0d  (expected 10)",                  uut.regfile_inst.regs[4]);
        $display("  R5 (LW R4-5, neg off)   Result: %0d (0x%02h)  (expected 85 / 0x55)",  uut.regfile_inst.regs[5], uut.regfile_inst.regs[5]);
        $display("  R6 (LW unwritten addr)  Result: %0d  (expected 0)",                   uut.regfile_inst.regs[6]);
        $display("------------------------------------------------");

        if (uut.regfile_inst.regs[1] !== 8'hAA) begin $display("  FAIL: R1"); errors=errors+1; end
        if (uut.regfile_inst.regs[2] !== 8'h55) begin $display("  FAIL: R2"); errors=errors+1; end
        if (uut.regfile_inst.regs[3] !== 8'hBB) begin $display("  FAIL: R3"); errors=errors+1; end
        if (uut.regfile_inst.regs[4] !== 8'd10) begin $display("  FAIL: R4"); errors=errors+1; end
        if (uut.regfile_inst.regs[5] !== 8'h55) begin $display("  FAIL: R5 (negative offset)"); errors=errors+1; end
        if (uut.regfile_inst.regs[6] !== 8'd0)  begin $display("  FAIL: R6 (should be 0)"); errors=errors+1; end

        if (errors == 0)
            $display("  RESULT: PASS -- all LW operations verified.");
        else
            $display("  RESULT: FAIL -- %0d check(s) failed.", errors);
        $display("------------------------------------------------");

        $finish;
    end

    always @(negedge clk) begin
        if (!rst)
            $display("  t=%0t | PC=%0d | Instr=0x%04h | R1=%0d R2=%0d R3=%0d R4=%0d R5=%0d R6=%0d",
                     $time, uut.pc_to_imem, current_instruction,
                     uut.regfile_inst.regs[1], uut.regfile_inst.regs[2],
                     uut.regfile_inst.regs[3], uut.regfile_inst.regs[4],
                     uut.regfile_inst.regs[5], uut.regfile_inst.regs[6]);
    end

endmodule

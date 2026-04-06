// tb_sw.v -- ISA Validation Testbench for the SW instruction
// Tests: SW rs2, rs1, imm6  =>  DMEM[rs1 + sign_extend(imm6)] = rs2
//
// Register values set via ADDI, then SW stores to memory.
// Testbench checks dmem contents directly (no dependency on LW).
// Test cases:
//   1. SW to addr 0 with zero offset
//   2. SW to addr 1 with immediate offset
//   3. SW with register base (R2=10, offset=0 -> DMEM[10])
//   4. SW with max positive offset (31)

`timescale 1ns / 1ps

module tb_sw;

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
        $dumpfile("sw_waves.vcd");
        $dumpvars(0, tb_sw);
    end

    initial begin
        errors = 0;
        rst = 1'b1;

        $readmemh("tests/isa_tests/program_sw_test.hex", uut.imem_inst.rom);
        $display("[TB] Loaded program_sw_test.hex");

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
        $display("  SW Validation Results");
        $display("------------------------------------------------");
        $display("  DMEM[0]  (SW R1,R0,0)    Result: %0d  (expected 25)", uut.dmem_inst.ram[0]);
        $display("  DMEM[1]  (SW R2,R0,1)    Result: %0d  (expected 10)", uut.dmem_inst.ram[1]);
        $display("  DMEM[10] (SW R1,R2,0)    Result: %0d  (expected 25)", uut.dmem_inst.ram[10]);
        $display("  DMEM[31] (SW R2,R0,31)   Result: %0d  (expected 10)", uut.dmem_inst.ram[31]);
        $display("  DMEM[2]  (untouched)     Result: %0d  (expected 0)",  uut.dmem_inst.ram[2]);
        $display("------------------------------------------------");

        if (uut.dmem_inst.ram[0]  !== 8'd25) begin $display("  FAIL: DMEM[0]");  errors=errors+1; end
        if (uut.dmem_inst.ram[1]  !== 8'd10) begin $display("  FAIL: DMEM[1]");  errors=errors+1; end
        if (uut.dmem_inst.ram[10] !== 8'd25) begin $display("  FAIL: DMEM[10]"); errors=errors+1; end
        if (uut.dmem_inst.ram[31] !== 8'd10) begin $display("  FAIL: DMEM[31]"); errors=errors+1; end
        if (uut.dmem_inst.ram[2]  !== 8'd0)  begin $display("  FAIL: DMEM[2] (should be untouched)"); errors=errors+1; end

        if (errors == 0)
            $display("  RESULT: PASS -- all SW operations verified.");
        else
            $display("  RESULT: FAIL -- %0d check(s) failed.", errors);
        $display("------------------------------------------------");

        $finish;
    end

    always @(negedge clk) begin
        if (!rst)
            $display("  t=%0t | PC=%0d | Instr=0x%04h | R1=%0d R2=%0d | DMEM[0]=%0d DMEM[1]=%0d DMEM[10]=%0d DMEM[31]=%0d",
                     $time, uut.pc_to_imem, current_instruction,
                     uut.regfile_inst.regs[1], uut.regfile_inst.regs[2],
                     uut.dmem_inst.ram[0], uut.dmem_inst.ram[1],
                     uut.dmem_inst.ram[10], uut.dmem_inst.ram[31]);
    end

endmodule

// tb_addi.v -- ISA Validation Testbench for the ADDI instruction
// Tests: ADDI rd, rs1, imm6  =>  rd = rs1 + sign_extend(imm6)
//
// Initial register values injected by testbench: R1=5, R2=10
// Expected results after execution:
//   R3 = 15  (ADDI R1, +10)
//   R4 = 2   (ADDI R1, -3)
//   R5 = 10  (ADDI R0, +10  -- R0 hardwired to 0)
//   R6 = 41  (ADDI R2, +31  -- max positive imm6)
//   R7 = 234 (ADDI R2, -32  -- min negative imm6, 10-32 wraps to 234)

`timescale 1ns / 1ps

module tb_addi;

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
        $dumpfile("addi_waves.vcd");
        $dumpvars(0, tb_addi);
    end

    initial begin
        errors = 0;
        rst = 1'b1;

        $readmemh("tests/isa_tests/program_addi_test.hex", uut.imem_inst.rom);
        $display("[TB] Loaded program_addi_test.hex");

        // Inject initial values
        uut.regfile_inst.regs[1] = 8'd5;
        uut.regfile_inst.regs[2] = 8'd10;
        $display("[TB] Injected: R1=%0d  R2=%0d",
                 uut.regfile_inst.regs[1], uut.regfile_inst.regs[2]);

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
        $display("  ADDI Validation Results (R1=5, R2=10)");
        $display("------------------------------------------------");
        $display("  R3 (ADDI R1+10)  Result: %0d  (expected 15)",  uut.regfile_inst.regs[3]);
        $display("  R4 (ADDI R1-3)   Result: %0d  (expected 2)",   uut.regfile_inst.regs[4]);
        $display("  R5 (ADDI R0+10)  Result: %0d  (expected 10)",  uut.regfile_inst.regs[5]);
        $display("  R6 (ADDI R2+31)  Result: %0d  (expected 41)",  uut.regfile_inst.regs[6]);
        $display("  R7 (ADDI R2-32)  Result: %0d  (expected 234)", uut.regfile_inst.regs[7]);
        $display("------------------------------------------------");

        if (uut.regfile_inst.regs[3] !== 8'd15)  begin $display("  FAIL: R3"); errors=errors+1; end
        if (uut.regfile_inst.regs[4] !== 8'd2)   begin $display("  FAIL: R4"); errors=errors+1; end
        if (uut.regfile_inst.regs[5] !== 8'd10)  begin $display("  FAIL: R5"); errors=errors+1; end
        if (uut.regfile_inst.regs[6] !== 8'd41)  begin $display("  FAIL: R6"); errors=errors+1; end
        if (uut.regfile_inst.regs[7] !== 8'd234) begin $display("  FAIL: R7"); errors=errors+1; end

        // R0 write-protection: ADDI R0, R1, 5 must not modify R0
        $display("  R0 (write-protect) Result: %0d  (expected 0)", uut.regfile_inst.regs[0]);
        if (uut.regfile_inst.regs[0] !== 8'd0) begin $display("  FAIL: R0 (write-protection broken)"); errors=errors+1; end

        if (errors == 0)
            $display("  RESULT: PASS -- all ADDI operations verified.");
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

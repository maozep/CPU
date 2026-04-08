// tb_simple_com.v -- ISA Validation Testbench for ADD, SUB, AND, OR
// Uses complementary bit patterns R1=0xA5, R2=0x5A to expose edge cases:
//   R3 = 255 (ADD: sum to max, 0xA5+0x5A=0xFF)
//   R4 = 181 (SUB: underflow wrap, 0x5A-0xA5=0xB5)
//   R5 = 0   (AND: complementary bits cancel, 0xA5&0x5A=0x00)
//   R6 = 255 (OR:  complementary bits fill, 0xA5|0x5A=0xFF)
//   R7 = 74  (ADD: overflow wrap, 0xA5+0xA5=0x4A)

`timescale 1ns / 1ps

module tb_simple_com;

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
        $dumpfile("simple_com_waves.vcd");
        $dumpvars(0, tb_simple_com);
    end

    initial begin
        errors = 0;
        rst = 1'b1;

        $readmemh("tests/isa_tests/program_simple_com.hex", uut.imem_inst.rom);
        $display("[TB] Loaded program_simple_com.hex");

        // Inject complementary bit patterns to expose ALU edge cases
        uut.regfile_inst.regs[1] = 8'hA5;  // 10100101
        uut.regfile_inst.regs[2] = 8'h5A;  // 01011010
        $display("[TB] Injected: R1=0x%02h (%0d)  R2=0x%02h (%0d)",
                 uut.regfile_inst.regs[1], uut.regfile_inst.regs[1],
                 uut.regfile_inst.regs[2], uut.regfile_inst.regs[2]);

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
        $display("  ALU Validation Results (R1=0xA5, R2=0x5A)");
        $display("------------------------------------------------");
        $display("  R3 (ADD R1+R2, sum-to-max)    Result: %0d  (expected 255)", uut.regfile_inst.regs[3]);
        $display("  R4 (SUB R2-R1, underflow)     Result: %0d  (expected 181)", uut.regfile_inst.regs[4]);
        $display("  R5 (AND R1&R2, complement)    Result: %0d  (expected 0)",   uut.regfile_inst.regs[5]);
        $display("  R6 (OR  R1|R2, complement)    Result: %0d  (expected 255)", uut.regfile_inst.regs[6]);
        $display("  R7 (ADD R1+R1, overflow wrap) Result: %0d  (expected 74)",  uut.regfile_inst.regs[7]);
        $display("------------------------------------------------");

        if (uut.regfile_inst.regs[3] !== 8'd255) begin $display("  FAIL: R3"); errors=errors+1; end
        if (uut.regfile_inst.regs[4] !== 8'd181) begin $display("  FAIL: R4"); errors=errors+1; end
        if (uut.regfile_inst.regs[5] !== 8'd0)   begin $display("  FAIL: R5"); errors=errors+1; end
        if (uut.regfile_inst.regs[6] !== 8'd255) begin $display("  FAIL: R6"); errors=errors+1; end
        if (uut.regfile_inst.regs[7] !== 8'd74)  begin $display("  FAIL: R7"); errors=errors+1; end

        if (errors == 0)
            $display("  RESULT: PASS -- all ALU operations verified.");
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

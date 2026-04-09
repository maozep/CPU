// tb_fibonacci.v -- Fibonacci Demo Testbench
// Computes fib(1)..fib(7) = 1, 1, 2, 3, 5, 8, 13
// Stores each value in DMEM[0..6], final fib(8)=21 in DMEM[7]
// Demonstrates: ADDI, ADD, SW, BNE loop, HALT

`timescale 1ns / 1ps

module tb_fibonacci;

    reg         clk;
    reg         rst;
    wire [15:0] current_instruction;
    wire [31:0] cycle_count;

    cpu uut (
        .clk                 (clk),
        .rst                 (rst),
        .current_instruction (current_instruction),
        .cycle_count         (cycle_count)
    );

    // 100 MHz clock (10ns period)
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Waveform dump -- this is the file you open in GTKWave
    initial begin
        $dumpfile("fibonacci_waves.vcd");
        $dumpvars(0, tb_fibonacci);

        // Also dump individual register values for clean waveform view
        $dumpvars(1, uut.regfile_inst.regs[1]);  // fib_prev
        $dumpvars(1, uut.regfile_inst.regs[2]);  // fib_curr
        $dumpvars(1, uut.regfile_inst.regs[3]);  // temp
        $dumpvars(1, uut.regfile_inst.regs[4]);  // addr/counter
        $dumpvars(1, uut.regfile_inst.regs[5]);  // limit

        // Dump DMEM slots where Fibonacci values land
        $dumpvars(1, uut.dmem_inst.ram[0]);
        $dumpvars(1, uut.dmem_inst.ram[1]);
        $dumpvars(1, uut.dmem_inst.ram[2]);
        $dumpvars(1, uut.dmem_inst.ram[3]);
        $dumpvars(1, uut.dmem_inst.ram[4]);
        $dumpvars(1, uut.dmem_inst.ram[5]);
        $dumpvars(1, uut.dmem_inst.ram[6]);
        $dumpvars(1, uut.dmem_inst.ram[7]);
    end

    integer tb_cc;

    initial begin
        rst = 1'b1;

        $readmemh("tests/demo/program_fibonacci.hex", uut.imem_inst.rom);
        $display("");
        $display("==========================================================");
        $display("  FIBONACCI DEMO -- 8-bit RISC CPU");
        $display("  Computing fib(1) through fib(8)");
        $display("==========================================================");

        @(posedge clk); #1;
        @(posedge clk); #1;
        rst = 1'b0;

        tb_cc = 0;
        while (current_instruction !== 16'h0000 && tb_cc < 200) begin
            @(posedge clk);
            tb_cc = tb_cc + 1;
        end
        @(posedge clk); #1;

        $display("");
        $display("  Execution complete: %0d hw cycles", cycle_count);
        $display("");
        $display("  Register File:");
        $display("    R1 (fib_prev)  = %0d", uut.regfile_inst.regs[1]);
        $display("    R2 (fib_curr)  = %0d", uut.regfile_inst.regs[2]);
        $display("    R4 (counter)   = %0d", uut.regfile_inst.regs[4]);
        $display("    R5 (limit)     = %0d", uut.regfile_inst.regs[5]);
        $display("");
        $display("  Fibonacci Sequence in DMEM:");
        $display("    DMEM[0] = %0d", uut.dmem_inst.ram[0]);
        $display("    DMEM[1] = %0d", uut.dmem_inst.ram[1]);
        $display("    DMEM[2] = %0d", uut.dmem_inst.ram[2]);
        $display("    DMEM[3] = %0d", uut.dmem_inst.ram[3]);
        $display("    DMEM[4] = %0d", uut.dmem_inst.ram[4]);
        $display("    DMEM[5] = %0d", uut.dmem_inst.ram[5]);
        $display("    DMEM[6] = %0d", uut.dmem_inst.ram[6]);
        $display("    DMEM[7] = %0d", uut.dmem_inst.ram[7]);
        $display("");

        // Verify
        if (uut.dmem_inst.ram[0] === 8'd1  &&
            uut.dmem_inst.ram[1] === 8'd1  &&
            uut.dmem_inst.ram[2] === 8'd2  &&
            uut.dmem_inst.ram[3] === 8'd3  &&
            uut.dmem_inst.ram[4] === 8'd5  &&
            uut.dmem_inst.ram[5] === 8'd8  &&
            uut.dmem_inst.ram[6] === 8'd13 &&
            uut.dmem_inst.ram[7] === 8'd21)
            $display("  RESULT: PASS -- Fibonacci sequence verified!");
        else
            $display("  RESULT: FAIL -- Sequence mismatch");

        $display("==========================================================");
        $display("");
        $finish;
    end

    // Per-cycle trace
    always @(negedge clk) begin
        if (!rst)
            $display("  [cycle %3d] PC=%2d | 0x%04h | R1=%3d R2=%3d R3=%3d R4=%3d",
                     cycle_count, uut.pc_to_imem, current_instruction,
                     uut.regfile_inst.regs[1], uut.regfile_inst.regs[2],
                     uut.regfile_inst.regs[3], uut.regfile_inst.regs[4]);
    end

endmodule

// tb_cpu.v -- Testbench for cpu (fetch integration)
// Verilog-2001. Requires program.hex in the simulation working directory.

`timescale 1ns/1ps

module tb_cpu;

    reg         clk;
    reg         rst;
    wire [15:0] current_instruction;

    // Unit under test: top-level CPU (PC + IMEM).
    cpu uut (
        .clk                 (clk),
        .rst                 (rst),
        .current_instruction (current_instruction)
    );

    // 10 ns period: toggle every 5 ns.
    always #5 clk = ~clk;

    initial begin
        // Known starting clock level and asserted reset before dumping/monitoring.
        clk = 1'b0;
        rst = 1'b1;

        // Waveform dump (entire testbench hierarchy).
        $dumpfile("cpu_waves.vcd");
        $dumpvars(0, tb_cpu);

        // Print time, reset, PC bus, and fetched instruction when any change.
        $monitor(
            "t=%0t  rst=%b  pc=0x%02h  current_instruction=0x%04h",
            $time,
            rst,
            uut.pc_to_imem,
            current_instruction
        );

        // Hold reset for exactly 20 ns, then release.
        #20;
        rst = 1'b0;

        // Observe sequential fetches as PC advances.
        #100;

        $finish;
    end

endmodule

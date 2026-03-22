`timescale 1ns/1ps

module tb_pc;
    reg        clk;
    reg        reset;
    wire [7:0] pc_out;

    pc dut (
        .clk(clk),
        .reset(reset),
        .pc_out(pc_out)
    );

    // Clock: 10 ns period
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Print PC after each clock edge (small delay so nonblocking updates are visible).
    always @(posedge clk) begin
        #0.1;
        $display("time=%0t  clk=1  reset=%b  pc_out=%0d (0x%02h)", $time, reset, pc_out, pc_out);
    end

    initial begin
        $dumpfile("pc_waves.vcd");
        $dumpvars(0, tb_pc);

        reset = 1'b1;
        #12;
        reset = 1'b0;

        // Run: 15 rising edges after release of initial reset (pc should reach 15).
        repeat (15) @(posedge clk);
        // Assert reset between clock edges so the 15th increment is visible before clear.
        #2;
        reset = 1'b1;
        #7;
        reset = 1'b0;

        // A few more cycles after mid reset
        repeat (5) @(posedge clk);

        $display("Simulation complete.");
        $finish;
    end
endmodule

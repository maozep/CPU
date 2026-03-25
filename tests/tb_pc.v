`timescale 1ns/1ps

module tb_pc;
    reg        clk;
    reg        reset;
    reg        is_branch;
    reg        is_bne;
    reg        zero;
    reg  [5:0] branch_offset;
    wire [7:0] pc_out;

    pc dut (
        .clk           (clk),
        .reset         (reset),
        .is_branch     (is_branch),
        .is_bne        (is_bne),
        .zero          (zero),
        .branch_offset (branch_offset),
        .pc_out        (pc_out)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        #0.1;
        $display("time=%0t  reset=%b  is_branch=%b  is_bne=%b  zero=%b  off=%0d  pc=%0d",
            $time, reset, is_branch, is_bne, zero, $signed({{2{branch_offset[5]}}, branch_offset}), pc_out);
    end

    initial begin
        $dumpfile("pc_waves.vcd");
        $dumpvars(0, tb_pc);

        is_branch     = 1'b0;
        is_bne        = 1'b0;
        zero          = 1'b0;
        branch_offset = 6'd0;

        reset = 1'b1;
        #12;
        reset = 1'b0;

        // Sequential: PC 0 -> 1 -> 2
        repeat (2) @(posedge clk);

        // BNE taken: not equal -> branch by PC+1+offset; offset=+1, expect PC 2 -> 4
        @(negedge clk);
        is_bne        = 1'b1;
        zero          = 1'b0;
        branch_offset = 6'd1;
        @(posedge clk);
        #0.1;
        if (pc_out !== 8'd4) begin
            $display("FAIL BNE-taken: expected pc=4, got %0d", pc_out);
        end else begin
            $display("PASS BNE-taken: PC branched to PC+1+offset");
        end

        // BNE not taken: equal -> PC+1 only (4 -> 5)
        @(negedge clk);
        is_bne        = 1'b1;
        zero          = 1'b1;
        branch_offset = 6'd1;
        @(posedge clk);
        #0.1;
        if (pc_out !== 8'd5) begin
            $display("FAIL BNE-not-taken: expected pc=5, got %0d", pc_out);
        end else begin
            $display("PASS BNE-not-taken: no branch when zero");
        end

        // BEQ still branches only when zero (sanity)
        @(negedge clk);
        is_bne        = 1'b0;
        is_branch     = 1'b1;
        zero          = 1'b1;
        branch_offset = 6'd2;
        @(posedge clk);
        #0.1;
        if (pc_out !== 8'd8) begin
            $display("FAIL BEQ: expected pc=8, got %0d", pc_out);
        end else begin
            $display("PASS BEQ: branch when zero");
        end

        $display("Simulation complete.");
        $finish;
    end
endmodule

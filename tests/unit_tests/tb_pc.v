`timescale 1ns/1ps

module tb_pc;
    reg        clk;
    reg        reset;
    reg        halt;
    reg        is_branch;
    reg        is_bne;
    reg        zero;
    reg  [5:0] branch_offset;
    wire [7:0] pc_out;

    pc dut (
        .clk           (clk),
        .reset         (reset),
        .halt          (halt),
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
        $display("time=%0t  reset=%b  halt=%b  is_branch=%b  is_bne=%b  zero=%b  off=%0d  pc=%0d",
            $time, reset, halt, is_branch, is_bne, zero, $signed({{2{branch_offset[5]}}, branch_offset}), pc_out);
    end

    initial begin
        $dumpfile("pc_waves.vcd");
        $dumpvars(0, tb_pc);

        is_branch     = 1'b0;
        is_bne        = 1'b0;
        halt          = 1'b0;
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
            $display("FAIL: BNE-taken expected pc=4, got %0d", pc_out);
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
            $display("FAIL: BNE-not-taken expected pc=5, got %0d", pc_out);
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
            $display("FAIL: BEQ expected pc=8, got %0d", pc_out);
        end else begin
            $display("PASS BEQ: branch when zero");
        end

        // Critical edge #1: maximum positive offset (+31): 8 -> 40
        @(negedge clk);
        is_branch     = 1'b1;
        is_bne        = 1'b0;
        zero          = 1'b1;
        branch_offset = 6'b01_1111; // +31
        @(posedge clk);
        #0.1;
        if (pc_out !== 8'd40) begin
            $display("FAIL: BEQ +31 expected pc=40, got %0d", pc_out);
        end else begin
            $display("PASS BEQ +31: max positive offset works");
        end

        // Critical edge #2: minimum negative offset (-32): 40 -> 9
        @(negedge clk);
        is_branch     = 1'b1;
        is_bne        = 1'b0;
        zero          = 1'b1;
        branch_offset = 6'b10_0000; // -32
        @(posedge clk);
        #0.1;
        if (pc_out !== 8'd9) begin
            $display("FAIL: BEQ -32 expected pc=9, got %0d", pc_out);
        end else begin
            $display("PASS BEQ -32: min negative offset works");
        end

        // Drive PC near wrap boundary using +31 from 9 repeatedly.
        repeat (7) begin
            @(negedge clk);
            is_branch     = 1'b1;
            is_bne        = 1'b0;
            zero          = 1'b1;
            branch_offset = 6'b01_1111; // +31
            @(posedge clk);
        end
        #0.1;
        if (pc_out !== 8'd233) begin
            $display("FAIL: pre-wrap setup expected pc=233, got %0d", pc_out);
        end else begin
            $display("PASS pre-wrap setup: PC prepared at 233");
        end

        // Critical edge #3: wrap-around with +31: 233 -> (233+1+31)=9
        @(negedge clk);
        is_branch     = 1'b1;
        is_bne        = 1'b0;
        zero          = 1'b1;
        branch_offset = 6'b01_1111; // +31
        @(posedge clk);
        #0.1;
        if (pc_out !== 8'd9) begin
            $display("FAIL: BEQ wrap +31 expected pc=9, got %0d", pc_out);
        end else begin
            $display("PASS BEQ wrap +31: 8-bit wrap-around verified");
        end

        // HALT behavior: PC must remain constant while halt is asserted.
        @(negedge clk);
        halt          = 1'b1;
        is_branch     = 1'b0;
        is_bne        = 1'b0;
        zero          = 1'b0;
        branch_offset = 6'd0;
        @(posedge clk);
        #0.1;
        if (pc_out !== 8'd9) begin
            $display("FAIL: HALT-freeze expected pc=9, got %0d", pc_out);
        end else begin
            $display("PASS HALT-freeze: PC held constant under halt");
        end

        @(negedge clk);
        halt = 1'b0;
        @(posedge clk);
        #0.1;
        if (pc_out !== 8'd10) begin
            $display("FAIL: HALT-release expected pc=10, got %0d", pc_out);
        end else begin
            $display("PASS HALT-release: PC resumed increment after halt deassert");
        end

        $display("Simulation complete.");
        $finish;
    end
endmodule

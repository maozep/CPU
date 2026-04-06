// tb_dmem.v -- Unit test for 256x8 Data Memory
// Tests: sync write, async read, address boundaries, overwrite, R/W independence

`timescale 1ns / 1ps

module tb_dmem;

    reg        clk;
    reg        we;
    reg  [7:0] addr;
    reg  [7:0] write_data;
    wire [7:0] read_data;

    integer errors;
    integer tests;

    dmem dut (
        .clk        (clk),
        .we         (we),
        .addr       (addr),
        .write_data (write_data),
        .read_data  (read_data)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task check_eq;
        input [7:0] got;
        input [7:0] exp;
        input [31:0] test_id;
        begin
            tests = tests + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("  FAIL: test %0d got=0x%02h exp=0x%02h", test_id, got, exp);
            end
        end
    endtask

    initial begin
        $dumpfile("dmem_waves.vcd");
        $dumpvars(0, tb_dmem);

        errors = 0;
        tests  = 0;
        we = 1'b0;
        addr = 8'd0;
        write_data = 8'd0;

        #2;

        // 1. Initial value should be zero
        addr = 8'd0; #1;
        check_eq(read_data, 8'h00, 1);
        addr = 8'd255; #1;
        check_eq(read_data, 8'h00, 2);

        // 2. Write to addr 10, read back
        @(negedge clk);
        we = 1'b1;
        addr = 8'd10;
        write_data = 8'hAB;
        @(negedge clk);
        we = 1'b0;
        #2;
        addr = 8'd10; #1;
        check_eq(read_data, 8'hAB, 3);

        // 3. Other addresses still zero
        addr = 8'd11; #1;
        check_eq(read_data, 8'h00, 4);

        // 4. Write to addr 0 and addr 255 (boundaries)
        @(negedge clk);
        we = 1'b1;
        addr = 8'd0;
        write_data = 8'hFF;
        @(negedge clk);
        addr = 8'd255;
        write_data = 8'h42;
        @(negedge clk);
        we = 1'b0;
        #2;
        addr = 8'd0; #1;
        check_eq(read_data, 8'hFF, 5);
        addr = 8'd255; #1;
        check_eq(read_data, 8'h42, 6);

        // 5. Overwrite: write new value to addr 10
        @(negedge clk);
        we = 1'b1;
        addr = 8'd10;
        write_data = 8'hCD;
        @(negedge clk);
        we = 1'b0;
        #2;
        addr = 8'd10; #1;
        check_eq(read_data, 8'hCD, 7);

        // 6. Write disabled: data should not change
        @(negedge clk);
        we = 1'b0;
        addr = 8'd10;
        write_data = 8'h00;
        @(negedge clk);
        #2;
        addr = 8'd10; #1;
        check_eq(read_data, 8'hCD, 8);

        // 7. Async read: change addr without clock edge, output updates immediately
        addr = 8'd0; #1;
        check_eq(read_data, 8'hFF, 9);
        addr = 8'd255; #1;
        check_eq(read_data, 8'h42, 10);

        $display("------------------------------------------------");
        if (errors == 0)
            $display("  RESULT: PASS -- %0d dmem tests passed.", tests);
        else
            $display("  RESULT: FAIL -- %0d/%0d tests failed.", errors, tests);
        $display("------------------------------------------------");

        $finish;
    end

endmodule

`timescale 1ns/1ps

module tb_regfile;
    reg         clk;
    reg         we;
    reg  [2:0]  read_addr1;
    reg  [2:0]  read_addr2;
    reg  [2:0]  write_addr;
    reg  [7:0]  write_data;
    wire [7:0]  read_data1;
    wire [7:0]  read_data2;

    regfile dut (
        .clk(clk),
        .we(we),
        .read_addr1(read_addr1),
        .read_addr2(read_addr2),
        .write_addr(write_addr),
        .write_data(write_data),
        .read_data1(read_data1),
        .read_data2(read_data2)
    );

    integer errors;
    integer tests;

    task check_eq;
        input [7:0] got;
        input [7:0] exp;
        input [31:0] test_id;
        begin
            tests = tests + 1;
            if (got !== exp) begin
                errors = errors + 1;
                $display("FAIL: test_id=%0d got=%h exp=%h (t=%0t)", test_id, got, exp, $time);
            end
        end
    endtask

    task check_zero;
        input [7:0] got;
        input [31:0] test_id;
        begin
            check_eq(got, 8'h00, test_id);
        end
    endtask

    // Clock: 10ns period
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("regfile_waves.vcd");
        $dumpvars(0, tb_regfile);

        errors = 0;
        tests  = 0;

        // Defaults
        we = 1'b0;
        read_addr1 = 3'b000;
        read_addr2 = 3'b000;
        write_addr = 3'b000;
        write_data = 8'h00;

        // Allow initial block init + a small time step
        #2;

        // R0 should read as 0 initially.
        check_zero(read_data1, 1);
        check_zero(read_data2, 2);

        // Write R1, R2, R7
        @(negedge clk);
        we = 1'b1;
        write_addr = 3'd1;
        write_data = 8'hAA;

        @(negedge clk);
        write_addr = 3'd2;
        write_data = 8'h55;

        @(negedge clk);
        write_addr = 3'd7;
        write_data = 8'h3C;

        @(negedge clk);
        we = 1'b0;
        write_addr = 3'd0;
        write_data = 8'h00;

        // Give time for last posedge write to take effect
        #2;

        // Verify synchronous writes took effect
        read_addr1 = 3'd1;
        read_addr2 = 3'd2;
        #1; // async read settle
        check_eq(read_data1, 8'hAA, 3);
        check_eq(read_data2, 8'h55, 4);

        read_addr1 = 3'd7;
        read_addr2 = 3'd0;
        #1; // async read settle
        check_eq(read_data1, 8'h3C, 5);
        check_zero(read_data2, 6);

        // Attempt to write non-zero to R0; should be ignored.
        @(negedge clk);
        we = 1'b1;
        write_addr = 3'd0;
        write_data = 8'hFF;

        @(negedge clk);
        we = 1'b0;
        write_addr = 3'd0;
        write_data = 8'h00;

        // Let the posedge pass
        #2;

        // R0 must remain 0
        read_addr1 = 3'd0;
        read_addr2 = 3'd1;
        #1;
        check_zero(read_data1, 7);
        check_eq(read_data2, 8'hAA, 8);

        // Explicit async read behavior check (no clock edge)
        // Change addresses and ensure outputs update immediately.
        read_addr1 = 3'd1;
        read_addr2 = 3'd2;
        #1;
        check_eq(read_data1, 8'hAA, 9);
        check_eq(read_data2, 8'h55, 10);

        read_addr1 = 3'd2;
        read_addr2 = 3'd7;
        #1;
        check_eq(read_data1, 8'h55, 11);
        check_eq(read_data2, 8'h3C, 12);

        if (errors == 0) begin
            $display("PASS: %0d tests passed.", tests);
        end else begin
            $display("DONE: %0d tests, %0d errors.", tests, errors);
        end

        $finish;
    end

endmodule


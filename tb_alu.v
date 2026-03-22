`timescale 1ns/1ps

module tb_alu;
    reg  [7:0] A;
    reg  [7:0] B;
    reg  [2:0] ALU_Control;
    wire [7:0] ALU_Result;
    wire        zero;

    reg  [7:0] vals [0:7];
    integer i, j;

    alu dut (
        .A(A),
        .B(B),
        .ALU_Control(ALU_Control),
        .ALU_Result(ALU_Result),
        .zero(zero)
    );

    integer errors;
    integer tests;

    // Checks one ALU operation for a single (A, B) pair.
    task check;
        input [2:0] control;
        input [7:0] a_in;
        input [7:0] b_in;
        reg   [7:0] exp;
        reg          exp_zero;
        begin
            ALU_Control = control;
            A = a_in;
            B = b_in;
            #1; // allow combinational outputs to settle

            case (control)
                3'b000: exp = (a_in + b_in) & 8'hFF; // ADD
                3'b001: exp = (a_in - b_in) & 8'hFF; // SUB
                3'b010: exp = a_in & b_in;           // AND
                3'b011: exp = a_in | b_in;           // OR
                default: exp = 8'h00;
            endcase

            exp_zero = (exp == 8'h00);
            tests = tests + 1;

            if (ALU_Result !== exp) begin
                errors = errors + 1;
                $display("FAIL: control=%b A=%h B=%h => ALU_Result=%h (expected %h)",
                    control, a_in, b_in, ALU_Result, exp);
            end

            if (zero !== exp_zero) begin
                errors = errors + 1;
                $display("FAIL: control=%b A=%h B=%h => zero=%b (expected %b)",
                    control, a_in, b_in, zero, exp_zero);
            end
        end
    endtask

    initial begin
        $dumpfile("alu_waves.vcd");
        $dumpvars(0, tb_alu);
        errors = 0;
        tests  = 0;

        // Explicit edge cases that should produce zero.
        check(3'b000, 8'h00, 8'h00); // ADD: 0 + 0 = 0
        check(3'b000, 8'hFF, 8'h01); // ADD: 255 + 1 = 0 (wrap)
        check(3'b000, 8'h80, 8'h80); // ADD: 128 + 128 = 0 (wrap)

        check(3'b001, 8'h00, 8'h00); // SUB: 0 - 0 = 0
        check(3'b001, 8'd5, 8'd5);   // SUB: 5 - 5 = 0 (zero flag)
        check(3'b001, 8'h12, 8'h12); // SUB: A - A = 0
        check(3'b001, 8'hFF, 8'hFF); // SUB: 255 - 255 = 0

        check(3'b010, 8'h00, 8'hAB); // AND: 0 & x = 0
        check(3'b010, 8'h0F, 8'hF0); // AND: 0000 -> 0
        check(3'b010, 8'hAA, 8'h55); // AND: pattern -> 0

        check(3'b011, 8'h00, 8'h00); // OR: 0 | 0 = 0
        check(3'b011, 8'h0F, 8'hF0); // OR: 0x0F | 0xF0 = 0xFF (non-zero)

        // Explicit underflow/overflow behavior (mod 256).
        check(3'b001, 8'h00, 8'h01); // SUB: 0 - 1 = 0xFF (wrap underflow)
        check(3'b000, 8'hFE, 8'h02); // ADD: 0xFE + 0x02 = 0x00 (wrap)

        // Broad sweep across representative values.
        vals[0] = 8'h00;
        vals[1] = 8'h01;
        vals[2] = 8'h02;
        vals[3] = 8'h03;
        vals[4] = 8'h7F;
        vals[5] = 8'h80;
        vals[6] = 8'hFE;
        vals[7] = 8'hFF;

        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                check(3'b000, vals[i], vals[j]); // ADD
                check(3'b001, vals[i], vals[j]); // SUB
                check(3'b010, vals[i], vals[j]); // AND
                check(3'b011, vals[i], vals[j]); // OR
            end
        end

        if (errors == 0) begin
            $display("PASS: %0d tests passed.", tests);
        end else begin
            $display("DONE: %0d tests, %0d errors.", tests, errors);
        end

        $finish;
    end
endmodule


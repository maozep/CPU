// cpu.v -- Top-level 8-bit CPU (instruction fetch path only)
// Verilog-2001. Connects program counter to instruction memory.

`timescale 1ns / 1ps

module cpu (
    input  wire       clk,
    input  wire       rst,
    output wire [7:0] current_instruction
);

    // PC output drives IMEM address (fetch address bus).
    wire [7:0] pc_to_imem;

    // Program counter: advances each clock when not in reset.
    pc pc_inst (
        .clk   (clk),
        .reset (rst),
        .pc_out(pc_to_imem)
    );

    // Instruction ROM: combinational read from program.hex image.
    imem imem_inst (
        .addr (pc_to_imem),
        .instr(current_instruction)
    );

endmodule

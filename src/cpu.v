// cpu.v -- Top-level 8-bit Harvard CPU (Fetch-Decode-Execute)
// Verilog-2001. Connects program counter to instruction memory and executes
// register-register ALU ops via control_unit.

`timescale 1ns / 1ps

module cpu (
    input  wire       clk,
    input  wire       rst,
    output wire [15:0] current_instruction
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

    // Decode: derive register addresses and ALU control from instruction.
    wire [3:0] opcode;
    wire [2:0] rd_addr;
    wire [2:0] rs1_addr;
    wire [2:0] rs2_addr;
    wire       reg_write;
    wire [2:0] alu_op;

    control_unit control_unit_inst (
        .instr     (current_instruction),
        .opcode    (opcode),
        .rd_addr   (rd_addr),
        .rs1_addr  (rs1_addr),
        .rs2_addr  (rs2_addr),
        .reg_write (reg_write),
        .alu_op    (alu_op)
    );

    // Register read operands (asynchronous dual-read)
    wire [7:0] rs1_data;
    wire [7:0] rs2_data;

    // ALU result (combinational)
    wire [7:0] alu_result;
    wire       alu_zero_unused;

    // Execute + writeback (single-cycle: regfile writes on posedge clk)
    wire reg_write_gated = reg_write & ~rst;

    regfile regfile_inst (
        .clk        (clk),
        .we         (reg_write_gated),
        .read_addr1 (rs1_addr),
        .read_addr2 (rs2_addr),
        .write_addr (rd_addr),
        .write_data (alu_result),
        .read_data1 (rs1_data),
        .read_data2 (rs2_data)
    );

    alu alu_inst (
        .A            (rs1_data),
        .B            (rs2_data),
        .ALU_Control (alu_op),
        .ALU_Result  (alu_result),
        .zero         (alu_zero_unused)
    );
endmodule

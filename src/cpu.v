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
    wire [5:0] branch_offset;
    assign branch_offset = current_instruction[5:0];

    // Program counter: advances each clock when not in reset.
    pc pc_inst (
        .clk          (clk),
        .reset        (rst),
        .halt         (is_halt),
        .is_branch    (is_branch),
        .is_bne       (is_bne),
        .zero         (alu_zero),
        .branch_offset(branch_offset),
        .pc_out       (pc_to_imem)
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
    wire       use_imm;
    wire       mem_read;
    wire       mem_write;
    wire       mem_to_reg;
    wire       is_branch;
    wire       is_bne;
    wire       is_halt;

    control_unit control_unit_inst (
        .instr     (current_instruction),
        .opcode    (opcode),
        .rd_addr   (rd_addr),
        .rs1_addr  (rs1_addr),
        .rs2_addr  (rs2_addr),
        .reg_write (reg_write),
        .alu_op    (alu_op),
        .use_imm   (use_imm),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .mem_to_reg(mem_to_reg),
        .is_branch (is_branch),
        .is_bne    (is_bne),
        .is_halt   (is_halt)
    );

    // Register read operands (asynchronous dual-read)
    wire [7:0] rs1_data;
    wire [7:0] rs2_data;

    // ADDI: sign-extend 6-bit immediate from instruction[5:0]
    wire [7:0] imm6_sext = {{2{current_instruction[5]}}, current_instruction[5:0]};

    // ALU second operand mux: register rs2 or sign-extended immediate
    wire [7:0] alu_b;
    assign alu_b = use_imm ? imm6_sext : rs2_data;

    // ALU result (combinational)
    wire [7:0] alu_result;
    wire       alu_zero;

    // Execute + writeback (single-cycle: regfile writes on posedge clk)
    wire reg_write_gated = reg_write & ~rst;

    // Write-back mux: memory read data (LW) or ALU result
    wire [7:0] dmem_read_data;
    wire [7:0] write_back_data;
    assign write_back_data = mem_to_reg ? dmem_read_data : alu_result;

    // Store data for SW: read from rs2 (control unit routes [11:9] to rs2_addr for SW)
    wire [7:0] store_data;
    assign store_data = rs2_data;

    regfile regfile_inst (
        .clk        (clk),
        .we         (reg_write_gated),
        .read_addr1 (rs1_addr),
        .read_addr2 (rs2_addr),
        .write_addr (rd_addr),
        .write_data (write_back_data),
        .read_data1 (rs1_data),
        .read_data2 (rs2_data)
    );

    alu alu_inst (
        .A            (rs1_data),
        .B            (alu_b),
        .ALU_Control (alu_op),
        .ALU_Result  (alu_result),
        .zero         (alu_zero)
    );

    // Data memory: address = ALU result (rs1 + imm6)
    wire mem_write_gated = mem_write & ~rst;

    dmem dmem_inst (
        .clk        (clk),
        .we         (mem_write_gated),
        .addr       (alu_result),
        .write_data (store_data),
        .read_data  (dmem_read_data)
    );
endmodule

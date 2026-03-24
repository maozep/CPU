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

    // Print key decode/execute signals each cycle (on falling edge for stability).
    always @(negedge clk) begin
        // Small delay so hierarchical/combinational nets settle.
        #0.1;
        $display(
            "Time=%0t | PC=%0d | Instr=0x%04h | rs1_val=0x%02h | rs2_val=0x%02h | Zero=%b | Is_Branch=%b | branch_offset=%0d | Next_PC=%0d",
            $time,
            uut.pc_to_imem,
            current_instruction,
            uut.rs1_data,
            uut.rs2_data,
            uut.alu_zero,
            uut.is_branch,
            $signed({{2{current_instruction[5]}}, current_instruction[5:0]}),
            ((uut.is_branch && uut.alu_zero) ? (uut.pc_to_imem + 8'd1 + {{2{current_instruction[5]}}, current_instruction[5:0]}) : (uut.pc_to_imem + 8'd1))
        );
    end

    initial begin
        // Known starting clock level and asserted reset before dumping/monitoring.
        clk = 1'b0;
        rst = 1'b1;

        // Waveform dump (entire testbench hierarchy).
        $dumpfile("cpu_waves.vcd");
        $dumpvars(0, tb_cpu);
        $display("VCD file should be generated now (cpu_waves.vcd).");

        // Print time, reset, PC bus, and fetched instruction when any change.
        $monitor(
            "t=%0t  rst=%b  pc=0x%02h  current_instruction=0x%04h",
            $time,
            rst,
            uut.pc_to_imem,
            current_instruction
        );

        // Forward branch test (positive offset): BEQ R1,R2,+1 at PC=0.
        // Encoding with current BEQ mapping:
        // opcode=5, rs1=1, rs2=2, offset=+1 => 16'h5281
        uut.imem_inst.rom[0] = 16'h5281;
        uut.imem_inst.rom[1] = 16'h0000;
        uut.imem_inst.rom[2] = 16'h0000;
        uut.imem_inst.rom[3] = 16'h0000;
        uut.regfile_inst.regs[1] = 8'd5;
        uut.regfile_inst.regs[2] = 8'd5;

        // Hold reset for exactly 20 ns, then release.
        #20;
        rst = 1'b0; // Wait for reset to finish
        #5;

        // Let one BEQ decision happen, then report (expected PC=2).
        @(posedge clk);
        #0.1;
        if (uut.pc_to_imem == 8'd2)
            $display("PASS Forward-BEQ: PC=%0d, Is_Branch=%b, Zero=%b", uut.pc_to_imem, uut.is_branch, uut.alu_zero);
        else
            $display("FAIL Forward-BEQ: PC=%0d (expected 2), Is_Branch=%b, Zero=%b", uut.pc_to_imem, uut.is_branch, uut.alu_zero);

        // Backward branch test (negative offset): BEQ at PC=10 with offset=-3.
        // offset=-3 in 6-bit two's complement is 6'b111101 (0x3D).
        // opcode=5, rs1=1, rs2=2, offset=0x3D => 16'h52BD
        rst = 1'b1;
        #2;
        uut.imem_inst.rom[10] = 16'h52BD;
        uut.pc_inst.pc_out = 8'd10;
        uut.regfile_inst.regs[1] = 8'd5;
        uut.regfile_inst.regs[2] = 8'd5;
        rst = 1'b0;
        #5;

        @(posedge clk);
        #0.1;
        if (uut.pc_to_imem == 8'd8)
            $display("PASS Backward-BEQ: PC=%0d, Is_Branch=%b, Zero=%b", uut.pc_to_imem, uut.is_branch, uut.alu_zero);
        else
            $display("FAIL Backward-BEQ: PC=%0d (expected 8), Is_Branch=%b, Zero=%b", uut.pc_to_imem, uut.is_branch, uut.alu_zero);

        // Observe sequential fetches as PC advances.
        #80;

        $finish;
    end

endmodule

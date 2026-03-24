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

        // program.hex in this repo is intentionally short; after a few addresses,
        // IMEM contents can become X. Keep prints deterministic for the first 5 bytes.
        if (uut.pc_to_imem <= 8'd4) begin
            $display(
                "Time=%0t | PC=%0d | Instr=0x%04h | rs1_val=0x%02h | rs2_val=0x%02h | Zero=%b | Is_Branch=%b | Next_PC=%0d",
                $time,
                uut.pc_to_imem,
                current_instruction,
                uut.rs1_data,
                uut.rs2_data,
                uut.alu_zero,
                uut.is_branch,
                ((uut.is_branch && uut.alu_zero) ? (uut.pc_to_imem + 8'd1 + {2'b00, current_instruction[5:0]}) : (uut.pc_to_imem + 8'd1))
            );
        end
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

        // Branch test #1 (taken): BEQ instruction in 4-digit hex.
        // Example requested: 0x5121
        uut.imem_inst.rom[0] = 16'h5121;
        uut.imem_inst.rom[1] = 16'h0000;
        uut.imem_inst.rom[2] = 16'h0000;
        uut.imem_inst.rom[3] = 16'h0000;
        uut.regfile_inst.regs[1] = 8'd10;
        uut.regfile_inst.regs[2] = 8'd10;

        // Hold reset for exactly 20 ns, then release.
        #20;
        rst = 1'b0; // Wait for reset to finish
        #5;

        // Let one BEQ decision happen, then report.
        @(posedge clk);
        #0.1;
        if (uut.pc_to_imem == 8'd34)
            $display("PASS BEQ-Taken: PC=%0d, Is_Branch=%b, Zero=%b", uut.pc_to_imem, uut.is_branch, uut.alu_zero);
        else
            $display("FAIL BEQ-Taken: PC=%0d (expected 34), Is_Branch=%b, Zero=%b", uut.pc_to_imem, uut.is_branch, uut.alu_zero);

        // Branch test #2 (not taken): same BEQ, but R1 != R2.
        // Reset PC to 0 to rerun from mem[0].
        rst = 1'b1;
        #2;
        uut.regfile_inst.regs[4] = 8'd1; // For 0x5121, rs2 decodes to R4
        rst = 1'b0;
        #5;

        @(posedge clk);
        #0.1;
        if (uut.pc_to_imem == 8'd1)
            $display("PASS BEQ-NotTaken: PC=%0d, Is_Branch=%b, Zero=%b", uut.pc_to_imem, uut.is_branch, uut.alu_zero);
        else
            $display("FAIL BEQ-NotTaken: PC=%0d (expected 1), Is_Branch=%b, Zero=%b", uut.pc_to_imem, uut.is_branch, uut.alu_zero);

        // Observe sequential fetches as PC advances.
        #80;

        $finish;
    end

endmodule

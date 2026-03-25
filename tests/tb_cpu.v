// tb_cpu.v -- Testbench for cpu (fetch integration)
// Verilog-2001. Requires program.hex in the simulation working directory.

`timescale 1ns/1ps

module tb_cpu;

    reg         clk;
    reg         rst;
    wire [15:0] current_instruction;
    reg         loop_passed;

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
            "Time=%0t | PC=%0d | Instr=0x%04h | rs1_val=0x%02h | rs2_val=0x%02h | Zero=%b | Is_Branch=%b | Is_BNE=%b | branch_offset=%0d | Next_PC=%0d",
            $time,
            uut.pc_to_imem,
            current_instruction,
            uut.rs1_data,
            uut.rs2_data,
            uut.alu_zero,
            uut.is_branch,
            uut.is_bne,
            $signed({{2{current_instruction[5]}}, current_instruction[5:0]}),
            (((uut.is_branch && uut.alu_zero) || (uut.is_bne && !uut.alu_zero))
                ? (uut.pc_to_imem + 8'd1 + {{2{current_instruction[5]}}, current_instruction[5:0]})
                : (uut.pc_to_imem + 8'd1))
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

        // BNE loop simulation (loaded from tests/program.hex by imem).
        // Before releasing reset, initialize registers needed by the loop.
        uut.regfile_inst.regs[7] = 8'd1; // The increment value
        uut.regfile_inst.regs[2] = 8'd5; // The target value
        loop_passed = 1'b0;

        // Hold reset for 20 ns, then release.
        #20;
        rst = 1'b0;

        // Run long enough to cover all 5 loop iterations.
        #500;

        if (loop_passed)
            $display("PASS: BNE loop reached HALT with R1=5.");
        else
            $display("FAIL: loop did not reach expected HALT state within #500. Final PC=%0d R1=%0d",
                     uut.pc_to_imem, uut.regfile_inst.regs[1]);
        $finish;
    end

    // Capture successful loop completion at runtime.
    always @(posedge clk) begin
        if (!rst && uut.pc_to_imem == 8'd3 && current_instruction == 16'h0000 && uut.regfile_inst.regs[1] == 8'd5)
            loop_passed <= 1'b1;
    end

endmodule

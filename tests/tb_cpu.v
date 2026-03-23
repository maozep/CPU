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
                "t=%0t PC=%0d opcode=0x%1h rs1_data=0x%02h rs2_data=0x%02h alu_result=0x%02h reg_write=%b",
                $time,
                uut.pc_to_imem,
                uut.opcode,
                uut.rs1_data,
                uut.rs2_data,
                uut.alu_result,
                uut.reg_write
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

        // Hold reset for exactly 20 ns, then release.
        #20;
        rst = 1'b0; // Wait for reset to finish

        // Wait a bit more so regfile internal state settles.
        #5;

        // Initialize Register File after reset deassertion.
        // NOTE: regs is an internal array inside src/regfile.v (simulation-only).
        uut.regfile_inst.regs[1] = 8'd10; // R1 = 10
        uut.regfile_inst.regs[2] = 8'd5;  // R2 = 5

        // Observe sequential fetches as PC advances.
        #120;

        $finish;
    end

endmodule

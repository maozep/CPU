// tb_simple_com.v -- ISA Validation Testbench for the Simple 8-bit CPU
// Validates ADD, SUB, OR, AND instructions using program_simple_com.hex.
// Verilog-2001. Run from the project root directory so relative paths resolve.
//
// Expected register values after execution (R1=1, R2=0 as initial inputs):
//   R3 = 2   (ADD R1+R1 = 1+1)
//   R4 = 0   (SUB R1-R1 = 1-1)
//   R5 = 1   (OR  R1|R1 = 1, then AND R1&R1 = 1  -> net: 1)
//   R6 = 0   (OR  R2|R1 = 1, then AND R2&R1 = 0  -> net: 0)
//   R7 = 0   (OR  R2|R2 = 0, then AND R2&R2 = 0  -> net: 0)

`timescale 1ns / 1ps

module tb_simple_com;

    // ----------------------------------------------------------------
    // 1. SIGNAL DECLARATIONS
    // ----------------------------------------------------------------
    reg         clk;                   // 100 MHz clock driving the CPU
    reg         rst;                   // Active-high synchronous reset
    wire [15:0] current_instruction;   // Instruction currently in the pipeline

    // Iteration counter to guard against runaway simulation.
    integer cycle_count;

    // ----------------------------------------------------------------
    // 2. UNIT UNDER TEST (UUT) — top-level cpu module
    // ----------------------------------------------------------------
    cpu uut (
        .clk                 (clk),
        .rst                 (rst),
        .current_instruction (current_instruction)
    );

    // ----------------------------------------------------------------
    // 3. CLOCK GENERATION — 100 MHz (10 ns period, toggle every 5 ns)
    // ----------------------------------------------------------------
    initial clk = 1'b0;
    always  #5 clk = ~clk;

    // ----------------------------------------------------------------
    // 4. WAVEFORM DUMP — open simple_com_waves.vcd for GTKWave
    // ----------------------------------------------------------------
    initial begin
        $dumpfile("simple_com_waves.vcd");
        $dumpvars(0, tb_simple_com);   // Dump all signals in this testbench
    end

    // ----------------------------------------------------------------
    // 5. MAIN STIMULUS
    // ----------------------------------------------------------------
    initial begin
        // --- 5a. Assert reset before anything else runs ----------------
        rst = 1'b1;

        // --- 5b. Load ISA test program into the CPU's instruction ROM ---
        // The $readmemh call uses a path relative to the simulation working
        // directory (project root). Inline // comments inside the hex file
        // are automatically ignored by the Verilog parser.
        $readmemh("tests/isa_tests/program_simple_com.hex", uut.imem_inst.rom);
        $display("[TB] Loaded program_simple_com.hex into instruction memory.");

        // --- 5c. Inject initial register values BEFORE reset releases ---
        // R0 is hard-wired to zero by the regfile; writing it has no effect.
        // R1 = 1  (first operand for all ALU instructions)
        // R2 = 0  (second operand for R6/R7 instructions)
        uut.regfile_inst.regs[1] = 8'd1;
        uut.regfile_inst.regs[2] = 8'd0;
        $display("[TB] Injected: R1=%0d  R2=%0d", uut.regfile_inst.regs[1],
                                                   uut.regfile_inst.regs[2]);

        // --- 5d. Hold reset for two full clock cycles then release ------
        // Two cycles ensures the PC and pipeline start cleanly from 0.
        @(posedge clk); #1;
        @(posedge clk); #1;
        rst = 1'b0;
        $display("[TB] Reset released at time %0t ns.", $time);

        // --- 5e. Run until HALT (0x0000) is fetched ---------------------
        // The CPU executes 9 instructions (PC 0-8); cap at 50 cycles as a
        // safety guard so simulation cannot loop forever on a logic error.
        cycle_count = 0;
        while (current_instruction !== 16'h0000 && cycle_count < 50) begin
            @(posedge clk);
            cycle_count = cycle_count + 1;
        end

        // Give the final register writeback one extra clock edge to settle.
        @(posedge clk); #1;

        // --- 5f. Check whether we stopped on HALT or timed out ----------
        if (current_instruction === 16'h0000) begin
            $display("[TB] HALT instruction detected at PC=%0d after %0d cycles.",
                     uut.pc_to_imem, cycle_count);
        end else begin
            $display("[TB] WARNING: simulation timed out without reaching HALT. PC=%0d",
                     uut.pc_to_imem);
        end

        // ----------------------------------------------------------------
        // 6. AUTOMATED RESULT VERIFICATION
        //    Print final register values with descriptive labels so the
        //    output is self-documenting without needing to open a waveform.
        // ----------------------------------------------------------------
        $display("------------------------------------------------");
        $display("  ISA Validation Results (R1=1, R2=0 inputs)");
        $display("------------------------------------------------");
        $display("  R3 (ADD  1+1)  Result: %0d  (expected 2)",
                 uut.regfile_inst.regs[3]);
        $display("  R4 (SUB  1-1)  Result: %0d  (expected 0)",
                 uut.regfile_inst.regs[4]);
        $display("  R5 (AND  1&1)  Result: %0d  (expected 1)",
                 uut.regfile_inst.regs[5]);
        $display("  R6 (AND  0&1)  Result: %0d  (expected 0)",
                 uut.regfile_inst.regs[6]);
        $display("  R7 (AND  0&0)  Result: %0d  (expected 0)",
                 uut.regfile_inst.regs[7]);
        $display("------------------------------------------------");

        // Simple pass/fail summary using Verilog equality checks.
        if (uut.regfile_inst.regs[3] === 8'd2 &&
            uut.regfile_inst.regs[4] === 8'd0 &&
            uut.regfile_inst.regs[5] === 8'd1 &&
            uut.regfile_inst.regs[6] === 8'd0 &&
            uut.regfile_inst.regs[7] === 8'd0)
            $display("  RESULT: PASS -- all ISA operations verified.");
        else
            $display("  RESULT: FAIL -- one or more registers hold unexpected values.");
        $display("------------------------------------------------");

        $finish;
    end

    // ----------------------------------------------------------------
    // 7. CYCLE-BY-CYCLE TRACE (printed on every falling edge for stable
    //    combinational values, mirroring the style of tb_cpu.v)
    // ----------------------------------------------------------------
    always @(negedge clk) begin
        if (!rst)
            $display("  t=%0t | PC=%0d | Instr=0x%04h | R3=%0d R4=%0d R5=%0d R6=%0d R7=%0d",
                     $time,
                     uut.pc_to_imem,
                     current_instruction,
                     uut.regfile_inst.regs[3],
                     uut.regfile_inst.regs[4],
                     uut.regfile_inst.regs[5],
                     uut.regfile_inst.regs[6],
                     uut.regfile_inst.regs[7]);
    end

endmodule

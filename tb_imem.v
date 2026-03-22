`timescale 1ns/1ps

module tb_imem;
    reg  [7:0] addr;
    wire [7:0] instr;

    imem dut (
        .addr(addr),
        .instr(instr)
    );

    /*
     * Dummy program.hex format for $readmemh:
     *
     *   - One 8-bit value per line, written in hexadecimal (no "0x" prefix).
     *   - Optional line comments with // (supported by Icarus Verilog in hex files).
     *   - First line loads into mem[0], second into mem[1], and so on.
     *
     * Example file (program.hex):
     *
     *   DE
     *   AD
     *   BE
     *   EF
     *   00
     *   11
     *
     * Run vvp from the directory that contains program.hex (usually the project root).
     */

    integer a;

    initial begin
        $dumpfile("imem_waves.vcd");
        $dumpvars(0, tb_imem);

        addr = 8'h00;
        #1;
        for (a = 0; a <= 5; a = a + 1) begin
            addr = a[7:0];
            #10;
            $display("addr=%0d (0x%02h)  instr=0x%02h", addr, addr, instr);
        end

        // Edge: last byte in the ROM image
        addr = 8'hFF;
        #10;
        $display("EDGE [High-address access]: addr=0x%02h (last location)  instr=0x%02h",
            addr, instr);

        // Edge: jump from a low address to mid-range in one step (async read)
        addr = 8'h02;
        #1;
        addr = 8'h80;
        #10;
        $display("EDGE [Random access jump]: after low addr, addr=0x%02h  instr=0x%02h",
            addr, instr);

        // Edge: return to first location
        addr = 8'h00;
        #10;
        $display("EDGE [Wrap-around / reset to start]: addr=0x%02h  instr=0x%02h (first instr)",
            addr, instr);

        $finish;
    end
endmodule

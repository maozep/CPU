module imem (
    input  wire [7:0] addr,
    output wire [15:0] instr
);

    reg [15:0] rom [0:255];
    integer i;

    initial begin
        // Initialize full ROM to zero to avoid X fetches beyond loaded lines.
        for (i = 0; i < 256; i = i + 1) begin
            rom[i] = 16'h0000;
        end
        $readmemh("tests/program.hex", rom);
    end

    assign instr = rom[addr];

endmodule

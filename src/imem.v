module imem (
    input  wire [7:0] addr,
    output wire [15:0] instr
);

    reg [15:0] mem [0:255];

    initial begin
        $readmemh("program.hex", mem);
    end

    assign instr = mem[addr];

endmodule

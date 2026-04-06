// dmem.v -- 256x8 Data Memory (synchronous write, asynchronous read)

module dmem (
    input  wire        clk,
    input  wire        we,
    input  wire [7:0]  addr,
    input  wire [7:0]  write_data,
    output wire [7:0]  read_data
);

    reg [7:0] ram [0:255];

    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1)
            ram[i] = 8'h00;
    end

    // Asynchronous read
    assign read_data = ram[addr];

    // Synchronous write
    always @(posedge clk) begin
        if (we)
            ram[addr] <= write_data;
    end

endmodule

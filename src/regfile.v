module regfile (
    input  wire        clk,
    input  wire        we,
    input  wire [2:0]  read_addr1,
    input  wire [2:0]  read_addr2,
    input  wire [2:0]  write_addr,
    input  wire [7:0]  write_data,
    output wire [7:0]  read_data1,
    output wire [7:0]  read_data2
);

    // 8 registers, 8-bit each
    reg [7:0] regs [0:7];

    // Asynchronous read (combinational)
    assign read_data1 = (read_addr1 == 3'b000) ? 8'h00 : regs[read_addr1];
    assign read_data2 = (read_addr2 == 3'b000) ? 8'h00 : regs[read_addr2];

    // Synchronous write (posedge clk), ignore writes to R0
    always @(posedge clk) begin
        if (we && (write_addr != 3'b000)) begin
            regs[write_addr] <= write_data;
        end
    end

    // Optional initialization for clean simulation starts
    integer i;
    initial begin
        // "Reset" initialization (there is no explicit rst port).
        regs[0] = 8'h00;
        regs[1] = 8'd10;
        regs[2] = 8'd5;
        for (i = 3; i < 8; i = i + 1) begin
            regs[i] = 8'h00;
        end
    end

endmodule


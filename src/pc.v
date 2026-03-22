module pc (
    input  wire       clk,
    input  wire       reset,
    output reg  [7:0] pc_out
);

    // Asynchronous reset: clear immediately when reset is asserted.
    // Otherwise increment on each rising clock edge (wraps 255 -> 0).
    always @(posedge clk or posedge reset) begin
        if (reset)
            pc_out <= 8'd0;
        else
            pc_out <= pc_out + 8'd1;
    end

endmodule

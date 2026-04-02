module pc (
    input  wire       clk,
    input  wire       reset,
    input  wire       halt,
    input  wire       is_branch,
    input  wire       is_bne,
    input  wire       zero,
    input  wire [5:0] branch_offset,
    output reg  [7:0] pc_out
);

    wire branch_taken;
    assign branch_taken = (is_branch && zero) || (is_bne && !zero);

    // Asynchronous reset: clear immediately when reset is asserted.
    // Otherwise increment on each rising clock edge.
    // BEQ branches when equal; BNE branches when not equal. Same signed offset.
    always @(posedge clk or posedge reset) begin
        if (reset)
            pc_out <= 8'd0;
        else if (halt)
            pc_out <= pc_out;
        else if (branch_taken)
            pc_out <= pc_out + 8'd1 + {{2{branch_offset[5]}}, branch_offset};
        else
            pc_out <= pc_out + 8'd1;
    end

endmodule

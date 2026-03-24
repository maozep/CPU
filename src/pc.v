module pc (
    input  wire       clk,
    input  wire       reset,
    input  wire       is_branch,
    input  wire       zero,
    input  wire [5:0] branch_offset,
    output reg  [7:0] pc_out
);

    // Asynchronous reset: clear immediately when reset is asserted.
    // Otherwise increment on each rising clock edge.
    // If BEQ is active and ALU zero is asserted, branch by (1 + offset).
    always @(posedge clk or posedge reset) begin
        if (reset)
            pc_out <= 8'd0;
        else if (is_branch && zero)
            pc_out <= pc_out + 8'd1 + {{2{branch_offset[5]}}, branch_offset};
        else
            pc_out <= pc_out + 8'd1;
    end

endmodule

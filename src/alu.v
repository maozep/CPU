module alu (
    input  wire [7:0] A,
    input  wire [7:0] B,
    input  wire [2:0] ALU_Control,
    output reg  [7:0] ALU_Result,
    output wire        zero
);

    // Combinational ALU
    always @* begin
        case (ALU_Control)
            3'b000: ALU_Result = A + B;   // ADD
            3'b001: ALU_Result = A - B;   // SUB
            3'b010: ALU_Result = A & B;   // AND
            3'b011: ALU_Result = A | B;   // OR
            3'b100: ALU_Result = A ^ B;   // XOR
            default: ALU_Result = 8'h00;  // Safe default
        endcase
    end

    assign zero = (ALU_Result == 8'b00000000);

endmodule



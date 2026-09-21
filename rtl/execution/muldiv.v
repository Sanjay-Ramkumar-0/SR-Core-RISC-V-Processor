// ============================================================
//  Multiply / Divide Unit (M-extension)
//  Maps to: execution/muldiv.py
//  Note: Combinational for simulation simplicity.
//        In real silicon this would be multi-cycle / pipelined.
// ============================================================

`include "utils/defines.vh"

module muldiv #(
    parameter XLEN = `XLEN
)(
    input  wire [XLEN-1:0] a,
    input  wire [XLEN-1:0] b,
    input  wire [4:0]      op,
    output reg  [XLEN-1:0] result
);

    // Full-width product for MULH* variants
    wire signed [2*XLEN-1:0] prod_ss = $signed(a) * $signed(b);
    wire        [2*XLEN-1:0] prod_uu = a * b;
    wire signed [2*XLEN-1:0] prod_su = $signed(a) * $signed({1'b0, b});

    always @(*) begin
        case (op)
            `ALU_MUL:    result = prod_ss[XLEN-1:0];
            `ALU_MULH:   result = prod_ss[2*XLEN-1:XLEN];
            `ALU_MULHSU: result = prod_su[2*XLEN-1:XLEN];
            `ALU_MULHU:  result = prod_uu[2*XLEN-1:XLEN];
            `ALU_DIV:    result = (b == 0) ? {XLEN{1'b1}} : $signed(a) / $signed(b);
            `ALU_DIVU:   result = (b == 0) ? {XLEN{1'b1}} : a / b;
            `ALU_REM:    result = (b == 0) ? a : $signed(a) % $signed(b);
            `ALU_REMU:   result = (b == 0) ? a : a % b;
            default:     result = {XLEN{1'b0}};
        endcase
    end

endmodule

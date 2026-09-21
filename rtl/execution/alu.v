// ============================================================
//  ALU - Arithmetic Logic Unit
//  Maps 1:1 to: execution/alu.py
// ============================================================

`include "utils/defines.vh"

module alu #(
    parameter XLEN = `XLEN
)(
    input  wire [XLEN-1:0] a,
    input  wire [XLEN-1:0] b,
    input  wire [4:0]      op,
    output reg  [XLEN-1:0] result,
    output wire            zero
);

    assign zero = (result == {XLEN{1'b0}});

    always @(*) begin
        case (op)
            `ALU_ADD  : result = a + b;
            `ALU_SUB  : result = a - b;
            `ALU_SLL  : result = a << b[$clog2(XLEN)-1:0];
            `ALU_SLT  : result = ($signed(a) < $signed(b)) ? {{(XLEN-1){1'b0}}, 1'b1} : {XLEN{1'b0}};
            `ALU_SLTU : result = (a < b) ? {{(XLEN-1){1'b0}}, 1'b1} : {XLEN{1'b0}};
            `ALU_XOR  : result = a ^ b;
            `ALU_SRL  : result = a >> b[$clog2(XLEN)-1:0];
            `ALU_SRA  : result = $signed(a) >>> b[$clog2(XLEN)-1:0];
            `ALU_OR   : result = a | b;
            `ALU_AND  : result = a & b;
            `ALU_LUI  : result = b;
            default   : result = {XLEN{1'b0}};
        endcase
    end

endmodule

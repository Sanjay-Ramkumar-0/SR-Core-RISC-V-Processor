// ============================================================
//  Branch Unit
//  Maps to: execution/branch_unit.py
//  Decides whether a branch is taken and computes the target.
// ============================================================

`include "utils/defines.vh"

module branch_unit #(
    parameter XLEN = `XLEN
)(
    input  wire [XLEN-1:0] rs1_data,
    input  wire [XLEN-1:0] rs2_data,
    input  wire [XLEN-1:0] pc,
    input  wire [XLEN-1:0] imm,
    input  wire [2:0]      funct3,
    input  wire            is_branch,
    input  wire            is_jal,
    input  wire            is_jalr,

    output reg             taken,
    output reg  [XLEN-1:0] target
);

    reg cond;

    always @(*) begin
        case (funct3)
            `BR_BEQ : cond = (rs1_data == rs2_data);
            `BR_BNE : cond = (rs1_data != rs2_data);
            `BR_BLT : cond = ($signed(rs1_data) <  $signed(rs2_data));
            `BR_BGE : cond = ($signed(rs1_data) >= $signed(rs2_data));
            `BR_BLTU: cond = (rs1_data <  rs2_data);
            `BR_BGEU: cond = (rs1_data >= rs2_data);
            default : cond = 1'b0;
        endcase
    end

    always @(*) begin
        taken  = 1'b0;
        target = pc + {{(XLEN-3){1'b0}}, 3'd4};   // default = PC+4

        if (is_jal) begin
            taken  = 1'b1;
            target = pc + imm;
        end
        else if (is_jalr) begin
            taken  = 1'b1;
            target = (rs1_data + imm) & ~{{(XLEN-1){1'b0}}, 1'b1}; // clear LSB
        end
        else if (is_branch && cond) begin
            taken  = 1'b1;
            target = pc + imm;
        end
    end

endmodule

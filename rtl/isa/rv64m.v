// ============================================================
//  rv64m.v
//  Maps to: isa/rv64m.py
//
//  M-extension control (MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU)
// ============================================================

`include "utils/defines.vh"

module rv64m (
    input  wire [6:0]       opcode,
    input  wire [2:0]       funct3,
    input  wire [6:0]       funct7,
    input  wire             is_op,         // only OP opcode carries M ops

    // Control outputs
    output reg              reg_write,
    output reg              is_muldiv,
    output reg  [4:0]       alu_op,
    output reg              valid_inst     // 1 if this unit claims the instruction
);

    always @(*) begin
        reg_write  = 1'b0;
        is_muldiv  = 1'b0;
        alu_op     = `ALU_ADD;
        valid_inst = 1'b0;

        // M-extension lives under OP opcode with funct7 == 0000001
        if (is_op && (funct7 == 7'b0000001)) begin
            reg_write  = 1'b1;
            is_muldiv  = 1'b1;
            valid_inst = 1'b1;

            case (funct3)
                3'b000: alu_op = `ALU_MUL;
                3'b001: alu_op = `ALU_MULH;
                3'b010: alu_op = `ALU_MULHSU;
                3'b011: alu_op = `ALU_MULHU;
                3'b100: alu_op = `ALU_DIV;
                3'b101: alu_op = `ALU_DIVU;
                3'b110: alu_op = `ALU_REM;
                3'b111: alu_op = `ALU_REMU;
                default: begin
                    alu_op     = `ALU_ADD;
                    valid_inst = 1'b0;
                end
            endcase
        end
    end

endmodule

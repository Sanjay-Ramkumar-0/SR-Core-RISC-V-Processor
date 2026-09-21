// ============================================================
//  rv32i.v  (also used for RV64I base)
//  Maps to: isa/rv64i.py
//
//  Generates control signals and ALU op for the base integer
//  instruction set (I-extension).
// ============================================================

`include "utils/defines.vh"

module rv32i #(
    parameter XLEN = `XLEN
)(
    // From decoder
    input  wire [6:0]       opcode,
    input  wire [2:0]       funct3,
    input  wire [6:0]       funct7,
    input  wire             is_branch_op,
    input  wire             is_jal_op,
    input  wire             is_jalr_op,
    input  wire             is_load_op,
    input  wire             is_store_op,
    input  wire             is_op_imm,
    input  wire             is_op,
    input  wire             is_lui,
    input  wire             is_auipc,

    // Control outputs
    output reg              reg_write,
    output reg              mem_read,
    output reg              mem_write,
    output reg              mem_to_reg,
    output reg              alu_src,       // 1 = immediate
    output reg              is_branch,
    output reg              is_jal,
    output reg              is_jalr,
    output reg              is_muldiv,     // always 0 here
    output reg  [4:0]       alu_op,
    output reg  [1:0]       mem_size,
    output reg              valid_inst     // 1 if this unit claims the instruction
);

    always @(*) begin
        // Defaults
        reg_write  = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;
        alu_src    = 1'b0;
        is_branch  = 1'b0;
        is_jal     = 1'b0;
        is_jalr    = 1'b0;
        is_muldiv  = 1'b0;
        alu_op     = `ALU_ADD;
        mem_size   = `MEM_WORD;
        valid_inst = 1'b0;

        // --------------------------------------------------------
        //  LUI
        // --------------------------------------------------------
        if (is_lui) begin
            reg_write  = 1'b1;
            alu_src    = 1'b1;
            alu_op     = `ALU_LUI;
            valid_inst = 1'b1;
        end

        // --------------------------------------------------------
        //  AUIPC
        // --------------------------------------------------------
        else if (is_auipc) begin
            reg_write  = 1'b1;
            alu_src    = 1'b1;
            alu_op     = `ALU_ADD;   // PC + imm
            valid_inst = 1'b1;
        end

        // --------------------------------------------------------
        //  JAL
        // --------------------------------------------------------
        else if (is_jal_op) begin
            reg_write  = 1'b1;
            is_jal     = 1'b1;
            valid_inst = 1'b1;
        end

        // --------------------------------------------------------
        //  JALR
        // --------------------------------------------------------
        else if (is_jalr_op) begin
            reg_write  = 1'b1;
            alu_src    = 1'b1;
            is_jalr    = 1'b1;
            alu_op     = `ALU_ADD;
            valid_inst = 1'b1;
        end

        // --------------------------------------------------------
        //  BRANCH
        // --------------------------------------------------------
        else if (is_branch_op) begin
            is_branch  = 1'b1;
            alu_op     = `ALU_SUB;
            valid_inst = 1'b1;
        end

        // --------------------------------------------------------
        //  LOAD
        // --------------------------------------------------------
        else if (is_load_op) begin
            reg_write  = 1'b1;
            mem_read   = 1'b1;
            mem_to_reg = 1'b1;
            alu_src    = 1'b1;
            alu_op     = `ALU_ADD;
            valid_inst = 1'b1;
            case (funct3)
                3'b000, 3'b100: mem_size = `MEM_BYTE;  // LB / LBU
                3'b001, 3'b101: mem_size = `MEM_HALF;  // LH / LHU
                3'b010:         mem_size = `MEM_WORD;  // LW
                3'b011:         mem_size = `MEM_DWORD; // LD (RV64)
                default:        mem_size = `MEM_WORD;
            endcase
        end

        // --------------------------------------------------------
        //  STORE
        // --------------------------------------------------------
        else if (is_store_op) begin
            mem_write  = 1'b1;
            alu_src    = 1'b1;
            alu_op     = `ALU_ADD;
            valid_inst = 1'b1;
            case (funct3)
                3'b000:  mem_size = `MEM_BYTE;
                3'b001:  mem_size = `MEM_HALF;
                3'b010:  mem_size = `MEM_WORD;
                3'b011:  mem_size = `MEM_DWORD;
                default: mem_size = `MEM_WORD;
            endcase
        end

        // --------------------------------------------------------
        //  OP-IMM  (ADDI, SLTI, XORI, ORI, ANDI, SLLI, SRLI, SRAI)
        // --------------------------------------------------------
        else if (is_op_imm) begin
            reg_write  = 1'b1;
            alu_src    = 1'b1;
            valid_inst = 1'b1;
            case (funct3)
                3'b000: alu_op = `ALU_ADD;
                3'b010: alu_op = `ALU_SLT;
                3'b011: alu_op = `ALU_SLTU;
                3'b100: alu_op = `ALU_XOR;
                3'b110: alu_op = `ALU_OR;
                3'b111: alu_op = `ALU_AND;
                3'b001: alu_op = `ALU_SLL;
                3'b101: alu_op = funct7[5] ? `ALU_SRA : `ALU_SRL;
                default: alu_op = `ALU_ADD;
            endcase
        end

        // --------------------------------------------------------
        //  OP  (ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND)
        //      (M-extension is handled by rv64m.v)
        // --------------------------------------------------------
        else if (is_op && (funct7 != 7'b0000001)) begin
            reg_write  = 1'b1;
            valid_inst = 1'b1;
            case (funct3)
                3'b000: alu_op = funct7[5] ? `ALU_SUB : `ALU_ADD;
                3'b001: alu_op = `ALU_SLL;
                3'b010: alu_op = `ALU_SLT;
                3'b011: alu_op = `ALU_SLTU;
                3'b100: alu_op = `ALU_XOR;
                3'b101: alu_op = funct7[5] ? `ALU_SRA : `ALU_SRL;
                3'b110: alu_op = `ALU_OR;
                3'b111: alu_op = `ALU_AND;
                default: alu_op = `ALU_ADD;
            endcase
        end
    end

endmodule

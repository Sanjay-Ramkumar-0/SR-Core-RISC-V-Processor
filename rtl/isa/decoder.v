// ============================================================
//  decoder.v
//  Maps to: isa/decoder.py
//
//  Pure decode: extracts fields + immediates.
//  Does NOT decide control signals (that is done in rv32i / rv64m).
// ============================================================

`include "utils/defines.vh"

module decoder #(
    parameter XLEN = `XLEN
)(
    input  wire [31:0]      inst,

    // Raw fields
    output wire [6:0]       opcode,
    output wire [4:0]       rd,
    output wire [2:0]       funct3,
    output wire [4:0]       rs1,
    output wire [4:0]       rs2,
    output wire [6:0]       funct7,

    // Immediates (sign-extended to XLEN)
    output reg  [XLEN-1:0]  imm_i,
    output reg  [XLEN-1:0]  imm_s,
    output reg  [XLEN-1:0]  imm_b,
    output reg  [XLEN-1:0]  imm_u,
    output reg  [XLEN-1:0]  imm_j,

    // Selected immediate based on opcode
    output reg  [XLEN-1:0]  imm,

    // Instruction class helpers (used by IF for prediction)
    output wire             is_branch_op,
    output wire             is_jal_op,
    output wire             is_jalr_op,
    output wire             is_load_op,
    output wire             is_store_op,
    output wire             is_op_imm,
    output wire             is_op,
    output wire             is_lui,
    output wire             is_auipc,
    output wire             is_system
);

    assign opcode  = inst[6:0];
    assign rd      = inst[11:7];
    assign funct3  = inst[14:12];
    assign rs1     = inst[19:15];
    assign rs2     = inst[24:20];
    assign funct7  = inst[31:25];

    // ------------------------------------------------------------
    //  Immediate extraction (matches decoder.py helpers)
    // ------------------------------------------------------------
    always @(*) begin
        // I-type
        imm_i = {{(XLEN-12){inst[31]}}, inst[31:20]};

        // S-type
        imm_s = {{(XLEN-12){inst[31]}}, inst[31:25], inst[11:7]};

        // B-type
        imm_b = {{(XLEN-13){inst[31]}}, inst[31], inst[7],
                 inst[30:25], inst[11:8], 1'b0};

        // U-type
        imm_u = {{(XLEN-32){inst[31]}}, inst[31:12], 12'b0};

        // J-type
        imm_j = {{(XLEN-21){inst[31]}}, inst[31], inst[19:12],
                 inst[20], inst[30:21], 1'b0};
    end

    // Selected immediate
    always @(*) begin
        case (opcode)
            `OPCODE_LOAD, `OPCODE_OP_IMM, `OPCODE_JALR:
                imm = imm_i;
            `OPCODE_STORE:
                imm = imm_s;
            `OPCODE_BRANCH:
                imm = imm_b;
            `OPCODE_LUI, `OPCODE_AUIPC:
                imm = imm_u;
            `OPCODE_JAL:
                imm = imm_j;
            default:
                imm = {XLEN{1'b0}};
        endcase
    end

    // ------------------------------------------------------------
    //  Instruction class flags (used by pipeline & predictor)
    // ------------------------------------------------------------
    assign is_branch_op = (opcode == `OPCODE_BRANCH);
    assign is_jal_op    = (opcode == `OPCODE_JAL);
    assign is_jalr_op   = (opcode == `OPCODE_JALR);
    assign is_load_op   = (opcode == `OPCODE_LOAD);
    assign is_store_op  = (opcode == `OPCODE_STORE);
    assign is_op_imm    = (opcode == `OPCODE_OP_IMM);
    assign is_op        = (opcode == `OPCODE_OP);
    assign is_lui       = (opcode == `OPCODE_LUI);
    assign is_auipc     = (opcode == `OPCODE_AUIPC);
    assign is_system    = (opcode == `OPCODE_SYSTEM);

endmodule

// ============================================================
//  Global Defines - RISC-V RV32I / RV64I Core
//  Mirrors the constants used across the Python simulator
// ============================================================

`ifndef DEFINES_VH
`define DEFINES_VH

// ------------------------------------------------------------
//  XLEN configuration (change to 64 for RV64)
// ------------------------------------------------------------
`define XLEN        32
`define XLEN_BYTES  (`XLEN/8)

// ------------------------------------------------------------
//  Opcodes
// ------------------------------------------------------------
`define OPCODE_LUI      7'b0110111
`define OPCODE_AUIPC    7'b0010111
`define OPCODE_JAL      7'b1101111
`define OPCODE_JALR     7'b1100111
`define OPCODE_BRANCH   7'b1100011
`define OPCODE_LOAD     7'b0000011
`define OPCODE_STORE    7'b0100011
`define OPCODE_OP_IMM   7'b0010011
`define OPCODE_OP       7'b0110011
`define OPCODE_MISC_MEM 7'b0001111
`define OPCODE_SYSTEM   7'b1110011
`define OPCODE_OP_IMM32 7'b0011011   // RV64
`define OPCODE_OP32     7'b0111011   // RV64

// ------------------------------------------------------------
//  ALU Operations
// ------------------------------------------------------------
`define ALU_ADD     5'b00000
`define ALU_SUB     5'b00001
`define ALU_SLL     5'b00010
`define ALU_SLT     5'b00011
`define ALU_SLTU    5'b00100
`define ALU_XOR     5'b00101
`define ALU_SRL     5'b00110
`define ALU_SRA     5'b00111
`define ALU_OR      5'b01000
`define ALU_AND     5'b01001
`define ALU_LUI     5'b01010
`define ALU_MUL     5'b01011
`define ALU_MULH    5'b01100
`define ALU_MULHSU  5'b01101
`define ALU_MULHU   5'b01110
`define ALU_DIV     5'b01111
`define ALU_DIVU    5'b10000
`define ALU_REM     5'b10001
`define ALU_REMU    5'b10010

// ------------------------------------------------------------
//  Branch Types (funct3)
// ------------------------------------------------------------
`define BR_BEQ   3'b000
`define BR_BNE   3'b001
`define BR_BLT   3'b100
`define BR_BGE   3'b101
`define BR_BLTU  3'b110
`define BR_BGEU  3'b111

// ------------------------------------------------------------
//  Memory Size
// ------------------------------------------------------------
`define MEM_BYTE  2'b00
`define MEM_HALF  2'b01
`define MEM_WORD  2'b10
`define MEM_DWORD 2'b11   // RV64

// ------------------------------------------------------------
//  Pipeline stage IDs (for debug)
// ------------------------------------------------------------
`define STAGE_IF   3'd0
`define STAGE_ID   3'd1
`define STAGE_EX   3'd2
`define STAGE_MEM  3'd3
`define STAGE_WB   3'd4

`endif

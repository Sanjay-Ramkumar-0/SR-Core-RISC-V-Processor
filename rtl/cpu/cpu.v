// ============================================================
//  Top-level CPU
//  Maps to: cpu/cpu.py
// ============================================================

`include "utils/defines.vh"

module cpu #(
    parameter XLEN = `XLEN
)(
    input  wire             clk,
    input  wire             rst_n,

    // External memory interface (simplified for now)
    output wire [XLEN-1:0]  imem_addr,
    input  wire [31:0]      imem_rdata,

    output wire [XLEN-1:0]  dmem_addr,
    output wire [XLEN-1:0]  dmem_wdata,
    output wire             dmem_we,
    output wire             dmem_re,
    output wire [1:0]       dmem_size,
    input  wire [XLEN-1:0]  dmem_rdata,
    input  wire             dmem_ready,

    // Debug
    output wire [XLEN-1:0]  debug_pc,
    output wire             debug_stall
);

    pipeline #(.XLEN(XLEN)) u_pipeline (
        .clk         (clk),
        .rst_n       (rst_n),
        .imem_addr   (imem_addr),
        .imem_rdata  (imem_rdata),
        .dmem_addr   (dmem_addr),
        .dmem_wdata  (dmem_wdata),
        .dmem_we     (dmem_we),
        .dmem_re     (dmem_re),
        .dmem_size   (dmem_size),
        .dmem_rdata  (dmem_rdata),
        .dmem_ready  (dmem_ready),
        .debug_pc    (debug_pc),
        .debug_stall (debug_stall)
    );

endmodule

// ============================================================
//  Address Generation Unit (AGU)
//  Maps to: execution/agu.py
//  Computes effective address for loads and stores.
// ============================================================

`include "utils/defines.vh"

module agu #(
    parameter XLEN = `XLEN
)(
    input  wire [XLEN-1:0] base,   // rs1
    input  wire [XLEN-1:0] offset, // immediate
    output wire [XLEN-1:0] addr
);

    assign addr = base + offset;

endmodule

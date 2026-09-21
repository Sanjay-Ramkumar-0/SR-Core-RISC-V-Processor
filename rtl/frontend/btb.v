// ============================================================
//  Branch Target Buffer (BTB)
//  Maps to: frontend/btb.py
//
//  Direct-mapped, stores predicted target address for a PC.
// ============================================================

`include "utils/defines.vh"

module btb #(
    parameter ENTRIES = 64,
    parameter XLEN    = `XLEN
)(
    input  wire             clk,
    input  wire             rst_n,

    // Lookup (IF stage)
    input  wire [XLEN-1:0]  pc,
    input  wire             lookup_en,
    output reg  [XLEN-1:0]  target,
    output reg              hit,

    // Update (after branch resolves)
    input  wire             update_en,
    input  wire [XLEN-1:0]  update_pc,
    input  wire [XLEN-1:0]  update_target
);

    localparam IDX_BITS = $clog2(ENTRIES);

    reg [XLEN-1:0] target_mem [0:ENTRIES-1];
    reg [XLEN-1:0] tag_mem    [0:ENTRIES-1];
    reg            valid      [0:ENTRIES-1];

    wire [IDX_BITS-1:0] idx        = pc[IDX_BITS+1:2];
    wire [IDX_BITS-1:0] update_idx = update_pc[IDX_BITS+1:2];

    integer i;

    // ------------------------------------------------------------
    //  Lookup (combinational)
    // ------------------------------------------------------------
    always @(*) begin
        hit    = 1'b0;
        target = {XLEN{1'b0}};
        if (lookup_en && valid[idx] && (tag_mem[idx] == pc)) begin
            hit    = 1'b1;
            target = target_mem[idx];
        end
    end

    // ------------------------------------------------------------
    //  Update
    // ------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < ENTRIES; i = i + 1) begin
                valid[i]      <= 1'b0;
                tag_mem[i]    <= {XLEN{1'b0}};
                target_mem[i] <= {XLEN{1'b0}};
            end
        end
        else if (update_en) begin
            valid[update_idx]      <= 1'b1;
            tag_mem[update_idx]    <= update_pc;
            target_mem[update_idx] <= update_target;
        end
    end

endmodule

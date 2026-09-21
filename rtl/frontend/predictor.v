// ============================================================
//  2-Bit Saturating Counter Branch Predictor
//  Maps to: frontend/predictor.py
//
//  States:
//    00 - Strongly Not Taken
//    01 - Weakly Not Taken
//    10 - Weakly Taken
//    11 - Strongly Taken
// ============================================================

`include "utils/defines.vh"

module branch_predictor #(
    parameter ENTRIES = 64,           // number of BHT entries
    parameter XLEN    = `XLEN
)(
    input  wire             clk,
    input  wire             rst_n,

    // Prediction request (IF stage)
    input  wire [XLEN-1:0]  pc,
    input  wire             predict_req,
    output reg              pred_taken,
    output reg              pred_valid,

    // Update (after branch resolves in EX/MEM)
    input  wire             update_en,
    input  wire [XLEN-1:0]  update_pc,
    input  wire             actual_taken
);

    // Branch History Table - 2 bits per entry
    // Indexed by lower bits of PC (word-aligned → drop [1:0])
    localparam IDX_BITS = $clog2(ENTRIES);
    reg [1:0] bht [0:ENTRIES-1];

    wire [IDX_BITS-1:0] pred_idx   = pc[IDX_BITS+1:2];
    wire [IDX_BITS-1:0] update_idx = update_pc[IDX_BITS+1:2];

    integer i;

    // ------------------------------------------------------------
    //  Prediction (combinational)
    // ------------------------------------------------------------
    always @(*) begin
        pred_valid = predict_req;
        if (predict_req)
            pred_taken = bht[pred_idx][1];   // MSB = taken prediction
        else
            pred_taken = 1'b0;
    end

    // ------------------------------------------------------------
    //  Update (sequential)
    // ------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < ENTRIES; i = i + 1)
                bht[i] <= 2'b01;             // weakly not taken
        end
        else if (update_en) begin
            case (bht[update_idx])
                2'b00: bht[update_idx] <= actual_taken ? 2'b01 : 2'b00;
                2'b01: bht[update_idx] <= actual_taken ? 2'b10 : 2'b00;
                2'b10: bht[update_idx] <= actual_taken ? 2'b11 : 2'b01;
                2'b11: bht[update_idx] <= actual_taken ? 2'b11 : 2'b10;
            endcase
        end
    end

endmodule

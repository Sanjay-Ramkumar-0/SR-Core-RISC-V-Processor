// ============================================================
//  Hazard Detection Unit
//  Maps to: cpu/hazard_unit.py
// ============================================================

module hazard_unit (
    input  wire [4:0] id_rs1,
    input  wire [4:0] id_rs2,
    input  wire       ex_mem_read,
    input  wire [4:0] ex_rd,

    output reg        stall,
    output reg        flush_id_ex
);

    always @(*) begin
        stall       = 1'b0;
        flush_id_ex = 1'b0;

        // Load-use hazard
        if (ex_mem_read && (ex_rd != 5'd0) &&
            ((ex_rd == id_rs1) || (ex_rd == id_rs2))) begin
            stall       = 1'b1;
            flush_id_ex = 1'b1;
        end
    end

endmodule

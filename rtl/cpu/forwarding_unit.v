// ============================================================
//  Data Forwarding Unit
//  Maps to: cpu/forwarding_unit.py
// ============================================================

module forwarding_unit (
    input  wire [4:0] ex_rs1,
    input  wire [4:0] ex_rs2,

    input  wire       mem_reg_write,
    input  wire [4:0] mem_rd,
    input  wire       wb_reg_write,
    input  wire [4:0] wb_rd,

    output reg  [1:0] forward_a,   // 00=reg, 01=MEM, 10=WB
    output reg  [1:0] forward_b
);

    always @(*) begin
        forward_a = 2'b00;
        forward_b = 2'b00;

        // EX hazard has priority
        if (mem_reg_write && (mem_rd != 5'd0) && (mem_rd == ex_rs1))
            forward_a = 2'b01;
        else if (wb_reg_write && (wb_rd != 5'd0) && (wb_rd == ex_rs1))
            forward_a = 2'b10;

        if (mem_reg_write && (mem_rd != 5'd0) && (mem_rd == ex_rs2))
            forward_b = 2'b01;
        else if (wb_reg_write && (wb_rd != 5'd0) && (wb_rd == ex_rs2))
            forward_b = 2'b10;
    end

endmodule

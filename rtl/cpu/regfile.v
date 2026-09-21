// ============================================================
//  Register File (32 x XLEN)
//  Maps to: cpu/thread_context.py register state
// ============================================================

`include "utils/defines.vh"

module regfile #(
    parameter XLEN = `XLEN
)(
    input  wire             clk,
    input  wire             rst_n,

    // Write port
    input  wire             we,
    input  wire [4:0]       waddr,
    input  wire [XLEN-1:0]  wdata,

    // Read ports
    input  wire [4:0]       raddr1,
    input  wire [4:0]       raddr2,
    output wire [XLEN-1:0]  rdata1,
    output wire [XLEN-1:0]  rdata2
);

    reg [XLEN-1:0] regs [0:31];
    integer i;

    assign rdata1 = (raddr1 == 5'd0) ? {XLEN{1'b0}} : regs[raddr1];
    assign rdata2 = (raddr2 == 5'd0) ? {XLEN{1'b0}} : regs[raddr2];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= {XLEN{1'b0}};
        end
        else if (we && (waddr != 5'd0)) begin
            regs[waddr] <= wdata;
        end
    end

endmodule

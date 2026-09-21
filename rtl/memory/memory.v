// ============================================================
//  main_memory.v
//  Behavioral byte-addressable memory for SIMULATION only.
//  Do NOT put this module in the OpenROAD synthesis file list.
// ============================================================

`include "utils/defines.vh"

module main_memory #(
    parameter DEPTH = 4096,
    parameter XLEN  = `XLEN
)(
    input  wire             clk,

    // Port A – instruction fetch (read-only, combinational)
    input  wire [XLEN-1:0]  i_addr,
    output reg  [31:0]      i_rdata,

    // Port B – data
    input  wire [XLEN-1:0]  d_addr,
    input  wire             d_re,
    input  wire             d_we,
    input  wire [1:0]       d_size,
    input  wire [XLEN-1:0]  d_wdata,
    output reg  [XLEN-1:0]  d_rdata
);

    reg [7:0] mem [0:DEPTH-1];
    integer i;

    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 8'h00;
    end

    // Instruction read (combinational, always word)
    always @(*) begin
        i_rdata = {mem[i_addr+3], mem[i_addr+2],
                   mem[i_addr+1], mem[i_addr+0]};
    end

    // Data read (combinational)
    always @(*) begin
        case (d_size)
            2'b00:   d_rdata = {{(XLEN-8){mem[d_addr][7]}}, mem[d_addr]};
            2'b01:   d_rdata = {{(XLEN-16){mem[d_addr+1][7]}},
                                mem[d_addr+1], mem[d_addr]};
            default: d_rdata = {mem[d_addr+3], mem[d_addr+2],
                                mem[d_addr+1], mem[d_addr]};
        endcase
    end

    // Data write (synchronous)
    always @(posedge clk) begin
        if (d_we) begin
            case (d_size)
                2'b00: begin
                    mem[d_addr] <= d_wdata[7:0];
                end
                2'b01: begin
                    mem[d_addr]   <= d_wdata[7:0];
                    mem[d_addr+1] <= d_wdata[15:8];
                end
                default: begin
                    mem[d_addr]   <= d_wdata[7:0];
                    mem[d_addr+1] <= d_wdata[15:8];
                    mem[d_addr+2] <= d_wdata[23:16];
                    mem[d_addr+3] <= d_wdata[31:24];
                end
            endcase
        end
    end

    // Helper for testbench program loading
    task load_word;
        input [XLEN-1:0] a;
        input [31:0]     d;
        begin
            mem[a+0] = d[7:0];
            mem[a+1] = d[15:8];
            mem[a+2] = d[23:16];
            mem[a+3] = d[31:24];
        end
    endtask

endmodule
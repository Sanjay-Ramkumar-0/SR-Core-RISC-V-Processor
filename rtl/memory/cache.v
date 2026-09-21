// ============================================================
//  Direct-Mapped Cache
//  Maps to: memory/cache.py + cache_line.py
//
//  Write-Through + Write-Allocate policy (same as Python model)
// ============================================================

`include "utils/defines.vh"

module cache #(
    parameter LINES      = 64,           // number of cache lines
    parameter LINE_BYTES = 16,           // bytes per line
    parameter XLEN       = `XLEN,
    parameter NAME       = "CACHE"
)(
    input  wire             clk,
    input  wire             rst_n,

    // CPU side
    input  wire [XLEN-1:0]  cpu_addr,
    input  wire             cpu_re,
    input  wire             cpu_we,
    input  wire [1:0]       cpu_size,
    input  wire [XLEN-1:0]  cpu_wdata,
    output reg  [XLEN-1:0]  cpu_rdata,
    output reg              cpu_ready,   // 1 = hit / data valid

    // Memory side (miss handling)
    output reg  [XLEN-1:0]  mem_addr,
    output reg              mem_re,
    output reg              mem_we,
    output reg  [1:0]       mem_size,
    output reg  [XLEN-1:0]  mem_wdata,
    input  wire [XLEN-1:0]  mem_rdata,
    input  wire             mem_ready
);

    localparam OFFSET_BITS = $clog2(LINE_BYTES);
    localparam INDEX_BITS  = $clog2(LINES);
    localparam TAG_BITS    = XLEN - INDEX_BITS - OFFSET_BITS;

    // Storage
    reg [TAG_BITS-1:0]   tag_array   [0:LINES-1];
    reg                  valid_array [0:LINES-1];
    reg [LINE_BYTES*8-1:0] data_array [0:LINES-1];

    // Address breakdown
    wire [OFFSET_BITS-1:0] offset = cpu_addr[OFFSET_BITS-1:0];
    wire [INDEX_BITS-1:0]  index  = cpu_addr[OFFSET_BITS +: INDEX_BITS];
    wire [TAG_BITS-1:0]    tag    = cpu_addr[XLEN-1 -: TAG_BITS];

    wire hit = valid_array[index] && (tag_array[index] == tag);

    // Simple hit/miss logic (combinational for hits)
    integer i;
    always @(*) begin
        cpu_ready  = 1'b0;
        cpu_rdata  = {XLEN{1'b0}};
        mem_re     = 1'b0;
        mem_we     = 1'b0;
        mem_addr   = {XLEN{1'b0}};
        mem_size   = `MEM_WORD;
        mem_wdata  = {XLEN{1'b0}};

        if (cpu_re || cpu_we) begin
            if (hit) begin
                cpu_ready = 1'b1;
                // Extract word/half/byte from the line
                case (cpu_size)
                    `MEM_BYTE: cpu_rdata = {{(XLEN-8){data_array[index][offset*8+7]}},
                                            data_array[index][offset*8 +: 8]};
                    `MEM_HALF: cpu_rdata = {{(XLEN-16){data_array[index][offset*8+15]}},
                                            data_array[index][offset*8 +: 16]};
                    default:   cpu_rdata = data_array[index][offset*8 +: XLEN];
                endcase
            end else begin
                // Miss → request from memory (simplified single-word for now)
                mem_re   = cpu_re;
                mem_we   = cpu_we;
                mem_addr = cpu_addr;
                mem_size = cpu_size;
                mem_wdata= cpu_wdata;
                if (mem_ready) begin
                    cpu_ready = 1'b1;
                    cpu_rdata = mem_rdata;
                end
            end
        end
    end

    // Update on miss fill / write-through
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < LINES; i = i + 1) begin
                valid_array[i] <= 1'b0;
                tag_array[i]   <= {TAG_BITS{1'b0}};
            end
        end
        else begin
            if ((cpu_re || cpu_we) && !hit && mem_ready) begin
                // Fill line (simplified: only the requested word)
                valid_array[index] <= 1'b1;
                tag_array[index]   <= tag;
                data_array[index][offset*8 +: XLEN] <= mem_rdata;
            end
            if (cpu_we && hit) begin
                // Write-through + update cache
                case (cpu_size)
                    `MEM_BYTE: data_array[index][offset*8 +: 8]  <= cpu_wdata[7:0];
                    `MEM_HALF: data_array[index][offset*8 +: 16] <= cpu_wdata[15:0];
                    default:   data_array[index][offset*8 +: XLEN] <= cpu_wdata;
                endcase
            end
        end
    end

endmodule
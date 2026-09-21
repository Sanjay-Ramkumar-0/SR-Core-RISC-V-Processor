// ============================================================
//  Top-level Testbench
//  Instantiates main (the same way main.py creates a CPU)
// ============================================================

`timescale 1ns/1ps
`include "utils/defines.vh"

module tb_cpu;

    localparam XLEN = `XLEN;

    reg  clk;
    reg  rst_n;
    wire [XLEN-1:0] debug_pc;
    wire            debug_stall;

    // DUT = main (top-level, mirrors main.py)
    main #(.XLEN(XLEN)) uut (
        .clk         (clk),
        .rst_n       (rst_n),
        .debug_pc    (debug_pc),
        .debug_stall (debug_stall)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // ------------------------------------------------------------
    //  Load a small test program into memory
    // ------------------------------------------------------------
    initial begin
        // Program:
        //   0x00: addi x1, x0, 10
        //   0x04: addi x2, x0, 20
        //   0x08: add  x3, x1, x2
        //   0x0C: sw   x3, 0(x0)
        //   0x10: lw   x4, 0(x0)
        //   0x14: beq  x3, x4, 8
        //   0x18: addi x5, x0, 99      // should be skipped
        //   0x1C: addi x5, x0, 1
        //   0x20: jal  x0, 0           // halt

        uut.u_memory.load_word(32'h00, 32'h00A00093);
        uut.u_memory.load_word(32'h04, 32'h01400113);
        uut.u_memory.load_word(32'h08, 32'h002081B3);
        uut.u_memory.load_word(32'h0C, 32'h00302023);
        uut.u_memory.load_word(32'h10, 32'h00002203);
        uut.u_memory.load_word(32'h14, 32'h00418463);
        uut.u_memory.load_word(32'h18, 32'h06300293);
        uut.u_memory.load_word(32'h1C, 32'h00100293);
        uut.u_memory.load_word(32'h20, 32'h0000006F);

        // Reset
        rst_n = 0;
        #20;
        rst_n = 1;

        // Run
        #800;

        $display("================================================");
        $display("  SR-Core RV32IM  (Verilog)");
        $display("  PC at end = 0x%08h", debug_pc);
        $display("  x1 = %0d (expect 10)", uut.u_cpu.u_pipeline.u_regfile.regs[1]);
        $display("  x2 = %0d (expect 20)", uut.u_cpu.u_pipeline.u_regfile.regs[2]);
        $display("  x3 = %0d (expect 30)", uut.u_cpu.u_pipeline.u_regfile.regs[3]);
        $display("  x4 = %0d (expect 30)", uut.u_cpu.u_pipeline.u_regfile.regs[4]);
        $display("  x5 = %0d (expect 1)",  uut.u_cpu.u_pipeline.u_regfile.regs[5]);
        $display("================================================");

        if (uut.u_cpu.u_pipeline.u_regfile.regs[1] == 10 &&
            uut.u_cpu.u_pipeline.u_regfile.regs[2] == 20 &&
            uut.u_cpu.u_pipeline.u_regfile.regs[3] == 30 &&
            uut.u_cpu.u_pipeline.u_regfile.regs[4] == 30 &&
            uut.u_cpu.u_pipeline.u_regfile.regs[5] == 1)
            $display("*** TEST PASSED ***");
        else
            $display("*** TEST FAILED ***");

        $finish;
    end

    initial begin
        $dumpfile("tb_cpu.vcd");
        $dumpvars(0, tb_cpu);
    end

endmodule

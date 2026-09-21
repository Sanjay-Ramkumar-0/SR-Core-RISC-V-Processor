#!/bin/bash
set -e
cd "$(dirname "$0")/.."

echo "=== Compiling SR-Core RTL ==="
iverilog -g2012 -o sim.out \
    -I rtl \
    rtl/utils/defines.vh \
    rtl/execution/alu.v \
    rtl/execution/muldiv.v \
    rtl/execution/branch_unit.v \
    rtl/execution/agu.v \
    rtl/frontend/predictor.v \
    rtl/frontend/btb.v \
    rtl/isa/decoder.v \
    rtl/isa/rv32i.v \
    rtl/isa/rv64m.v \
    rtl/memory/memory.v \
    rtl/memory/cache.v \
    rtl/cpu/regfile.v \
    rtl/cpu/hazard_unit.v \
    rtl/cpu/forwarding_unit.v \
    rtl/cpu/pipeline.v \
    rtl/cpu/cpu.v \
    rtl/main.v \
    tb/tb_cpu.v

echo "=== Running simulation ==="
vvp sim.out
echo "=== Done ==="

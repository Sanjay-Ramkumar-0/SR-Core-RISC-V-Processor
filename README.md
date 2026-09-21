# SR-Core – RISC-V Pipelined Processor (Verilog)

Deeply modular RTL that mirrors the structure of the Python SR-Core simulator.

```
riscv-rtl/
├── rtl/
│   ├── main.v                 ← main.py          (top-level entry)
│   │
│   ├── cpu/                   ← cpu/
│   │   ├── cpu.v
│   │   ├── pipeline.v
│   │   ├── regfile.v
│   │   ├── hazard_unit.v
│   │   └── forwarding_unit.v
│   │
│   ├── execution/             ← execution/
│   │   ├── alu.v
│   │   ├── branch_unit.v
│   │   ├── agu.v
│   │   └── muldiv.v
│   │
│   ├── frontend/              ← frontend/
│   │   ├── predictor.v
│   │   └── btb.v
│   │
│   ├── isa/                   ← isa/          ★ three files like Python
│   │   ├── decoder.v              (decoder.py)
│   │   ├── rv32i.v                (rv64i.py)
│   │   └── rv64m.v                (rv64m.py)
│   │
│   ├── memory/                ← memory/
│   │   ├── memory.v
│   │   └── cache.v
│   │
│   └── utils/
│       └── defines.vh
│
├── tb/
│   └── tb_cpu.v
├── scripts/
│   └── run_sim.sh
└── README.md
```

## ISA Layer (matches your three Python files)

| Python file     | Verilog file     | Responsibility                              |
|-----------------|------------------|---------------------------------------------|
| `decoder.py`    | `isa/decoder.v`  | Field extraction + all immediates           |
| `rv64i.py`      | `isa/rv32i.v`    | Base integer control signals + ALU op       |
| `rv64m.py`      | `isa/rv64m.v`    | M-extension control (MUL/DIV/REM family)    |

The pipeline instantiates all three and merges their outputs exactly the way the Python CPU dispatches to RV64I / RV64M.

## Top-level

`rtl/main.v` is the direct counterpart of `main.py`:
- Creates the CPU
- Connects main memory
- Exposes debug ports

## How to run

```bash
cd riscv-rtl
./scripts/run_sim.sh
```

Requires Icarus Verilog. Expected output ends with:

```
*** TEST PASSED ***
```

## Feature matrix

| Feature                      | Status      |
|-----------------------------|-------------|
| 5-stage pipeline            | ✓           |
| Hazard detection + stall    | ✓           |
| Data forwarding             | ✓           |
| 2-bit branch predictor      | ✓           |
| BTB                         | ✓           |
| RV32I base                  | ✓           |
| M-extension                 | ✓           |
| Parameterised XLEN (32/64)  | ✓           |
| Direct-mapped cache         | Present     |
| Full cache-line fill        | Simplified  |

The organisation is intentionally parallel to your Python project so you can keep extending both side-by-side.

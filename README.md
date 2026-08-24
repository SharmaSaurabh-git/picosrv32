# Picosrv32: A Pipelined RISC-V CPU Core

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![HDL: SystemVerilog](https://img.shields.io/badge/HDL-SystemVerilog-blue.svg)](https://en.wikipedia.org/wiki/SystemVerilog)
[![Simulator: Icarus Verilog](https://img.shields.io/badge/Simulator-Icarus%20Verilog%2012.0-green.svg)](http://iverilog.icarus.com/)
[![Tests: 14/14 passing](https://img.shields.io/badge/tests-14%2F14%20passing-brightgreen.svg)](#testing)

A 5-stage pipelined RISC-V CPU core implementing a subset of RV32I,
with real data hazard forwarding, a load-use stall, and branch
resolution with pipeline flush.

## Status

An earlier version of this repository had its control logic mostly
stubbed out: the program counter was hardcoded to 0 (so the CPU could
never fetch past the first instruction), the ALU's second operand
always used the immediate value (so register-register instructions
like `ADD` were structurally impossible), the ALU operation was
hardcoded to always add, and the hazard-detection signals were
declared but never assigned. The code didn't even compile — two
identifiers (`RESET_VECTOR`, `mem_wb_mem_to_reg`) were referenced but
never declared.

This version replaces that with an actual working pipeline: a real PC
register, full instruction decode for R-type/I-type ALU ops, loads,
stores, and branches, full EX/MEM + MEM/WB forwarding to the ALU, a
same-cycle register-file write-then-read bypass, a load-use stall, and
branch resolution in EX with a pipeline flush on taken branches.

**Verified:** a 16-instruction test program exercising every hazard
type above (back-to-back ALU dependencies, a store/load pair, a
load-use stall, two taken branches with squashed wrong-path
instructions) produces the correct final register and memory state —
14 checks, all passing. See [Testing](#testing) to reproduce.

## Instruction Set Support

**Implemented and verified:**
- R-type ALU: `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SLL`, `SRL`, `SRA`
- I-type ALU: `ADDI`, `ANDI`, `ORI`, `XORI`, `SLLI`, `SRLI`, `SRAI`
- Memory: `LW`, `SW`
- Branches: `BEQ`, `BNE`

**Not implemented** (decoded as harmless no-ops, do not affect other
instructions, but produce no useful result themselves): `LUI`,
`AUIPC`, `JAL`, `JALR`, `SLT`/`SLTU`/`SLTI`, other load/store widths
(`LB`/`LH`/etc.), `FENCE`, `ECALL`/`EBREAK`.

## Hazard Handling

- **Data hazards (RAW):** full forwarding from EX/MEM and MEM/WB back
  into the EX stage's ALU operands, plus a same-cycle bypass in the
  register file read logic for the case where WB and ID access the
  same register in the same cycle.
- **Load-use hazard:** a `LW` immediately followed by an instruction
  that needs its result can't be solved by forwarding alone (the
  loaded value isn't available until MEM), so the pipeline stalls for
  exactly one cycle.
- **Control hazards:** branches resolve in EX. A taken branch flushes
  the one wrong-path instruction already fetched into IF/ID and
  redirects the PC — see `doc/architecture.md` for why only one
  instruction needs squashing here, not two.

## Repository Structure
```
picosrv32/
├── rtl/
│   └── picosrv32.sv      # CPU pipeline + ALU
├── tb/
│   └── tb_picosrv32.sv   # Self-checking testbench
├── doc/
│   └── architecture.md   # Pipeline design, hazard handling, scope
└── README.md
```

## Getting Started
1. Clone: `git clone https://github.com/SharmaSaurabh-git/picosrv32.git`
2. Install Icarus Verilog: `pkg install iverilog` (Termux) or
   `sudo apt-get install iverilog` (Debian/Ubuntu)
3. Compile and simulate: `make sim-iverilog`
4. View waveform (optional, needs a GUI): `gtkwave picosrv32.vcd`

`make sim` (Verilator, `--binary` mode) should also work but is
untested in this repo's history — `make sim-iverilog` is what this
design was actually verified with.

## Testing
```bash
make sim-iverilog
```
Runs a 16-instruction program covering every hazard type the pipeline
handles, and checks final register/memory state against expected
values computed independently. Expected output ends with
`All tests PASSED.`

## Pipeline Stages
1. **IF** — fetch from instruction memory using the PC
2. **ID** — decode opcode/funct3/funct7, read registers (with
   same-cycle WB bypass), select immediate format
3. **EX** — forward operands from EX/MEM and MEM/WB, run the ALU,
   resolve branches
4. **MEM** — access data memory for loads/stores
5. **WB** — write the result back to the register file

## Future Enhancements
- `LUI`/`AUIPC`/`JAL`/`JALR` (currently unimplemented no-ops)
- `SLT`/`SLTU`/`SLTI` comparison instructions
- Byte/halfword loads and stores (`LB`/`LH`/`LBU`/`LHU`/`SB`/`SH`)
- Branch prediction (currently always-not-taken until EX resolves)
- A proper memory system (currently a flat combinational array in the
  testbench, not a real memory hierarchy)

## License
MIT

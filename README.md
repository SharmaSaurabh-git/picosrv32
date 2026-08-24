# Picosrv32: A Pipelined RISC-V CPU Core

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![HDL: SystemVerilog](https://img.shields.io/badge/HDL-SystemVerilog-blue.svg)](https://en.wikipedia.org/wiki/SystemVerilog)
[![Simulator: Icarus Verilog](https://img.shields.io/badge/Simulator-Icarus%20Verilog%2012.0-green.svg)](http://iverilog.icarus.com/)
[![Tests: 14/14 passing](https://img.shields.io/badge/tests-14%2F14%20passing-brightgreen.svg)](#testing)

A 5-stage pipelined RISC-V core, RV32I subset. Real forwarding, a
load-use stall, branches that actually resolve and flush correctly.
Not a toy that just compiles — it runs a program and gets the right
answer.

## Contents
- [Status](#status)
- [What it actually runs](#what-it-actually-runs)
- [Hazards, briefly](#hazards-briefly)
- [Repo layout](#repo-layout)
- [Running it](#running-it)
- [Testing](#testing)
- [The 5 stages, quickly](#the-5-stages-quickly)
- [Still missing](#still-missing)
- [License](#license)

## Status

Earlier version of this repo looked like a pipeline but wasn't one.
PC was hardcoded to 0, so it could never fetch past the first
instruction. The ALU's second operand was hardcoded to the immediate,
meaning `ADD rd, rs1, rs2` couldn't work even in theory. ALU op was
hardcoded to add, always. Hazard signals were declared and then never
touched again. It didn't even compile — two identifiers were used but
never declared anywhere.

None of that was reachable in simulation, by the way, which is
probably why nobody caught it. If the PC never moves, you never
execute a second instruction, so a stall bug three instructions later
just... never comes up.

Rewrote it. Real PC register, full decode for R-type/I-type ALU ops,
loads, stores, branches. EX/MEM and MEM/WB forwarding into the ALU. A
same-cycle bypass in the register file (write and read the same
register in the same cycle, you get the write). Load-use stall.
Branches resolve in EX and flush the pipeline correctly on a taken
branch.

Ran a 16-instruction program through it that hits every hazard type
above — back-to-back ALU dependencies, a store immediately followed by
a load from the same address, a load-use hazard, two taken branches
with instructions that should get squashed. 14 checks, all correct.
Command's below if you want to run it yourself.

## What it actually runs

R-type: `ADD` `SUB` `AND` `OR` `XOR` `SLL` `SRL` `SRA`
I-type: `ADDI` `ANDI` `ORI` `XORI` `SLLI` `SRLI` `SRAI`
Memory: `LW` `SW`
Branches: `BEQ` `BNE`

That's it for now. `LUI`, `AUIPC`, `JAL`, `JALR`, the `SLT` family,
byte/halfword loads and stores, `FENCE`, `ECALL`/`EBREAK` — none of
that's wired up. They decode as harmless no-ops (won't corrupt
anything else running), they just don't do anything useful themselves.

## Hazards, briefly

RAW hazards get fixed by forwarding — EX/MEM first, then MEM/WB if
EX/MEM doesn't have it, then whatever the register file already gave
you in ID. Plus that same-cycle write/read bypass I mentioned above.

Load-use is the one forwarding can't fix on its own, since the loaded
value literally doesn't exist yet until MEM. One-cycle stall, that's
it.

Branches resolve in EX because that's where the ALU lives and you
need the ALU to know if the branch is taken. By the time a branch
gets there, exactly one wrong-path instruction has already been
fetched behind it — not two, just one, because the PC hasn't caught
up to the fall-through address yet. So a taken branch squashes that
one instruction and redirects the PC. Full reasoning's in
`doc/architecture.md` if you want the cycle-by-cycle version.

## Repo layout
```
picosrv32/
├── rtl/
│   └── picosrv32.sv      # CPU pipeline + ALU
├── tb/
│   └── tb_picosrv32.sv   # self-checking testbench
├── doc/
│   └── architecture.md   # design writeup, hazard handling, what's not done
└── README.md
```

## Running it

```
git clone https://github.com/SharmaSaurabh-git/picosrv32.git
cd picosrv32
pkg install iverilog        # or: sudo apt-get install iverilog
make sim-iverilog
```

Want the waveform? `gtkwave picosrv32.vcd` after running, if you've
got a GUI available.

There's also a `make sim` target for Verilator (`--binary` mode) but
I haven't actually run that one — `make sim-iverilog` is what this was
verified against, so use that if you want the tested path.

## Testing
```bash
make sim-iverilog
```
Runs the 16-instruction program, checks the final register file and
memory state against values worked out independently (not just "did
it crash"). Ends with `All tests PASSED.` if everything's right.

## The 5 stages, quickly

1. **IF** — fetch, PC-driven
2. **ID** — decode opcode/funct3/funct7, read registers (with the WB
   bypass), pick the right immediate format
3. **EX** — forward operands, run the ALU, resolve branches here
4. **MEM** — load/store to data memory
5. **WB** — write back to the register file

## Still missing
- `LUI` / `AUIPC` / `JAL` / `JALR`
- `SLT` / `SLTU` / `SLTI`
- byte and halfword loads/stores — only `LW`/`SW` right now
- branch prediction — right now it just eats the one-cycle penalty
  every taken branch, no prediction at all
- an actual memory system — right now it's a flat array in the
  testbench, not anything resembling a cache

## License
MIT

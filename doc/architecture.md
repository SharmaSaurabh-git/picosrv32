# Picosrv32 Architecture

## Overview
Picosrv32 is a 5-stage pipelined RISC-V core (RV32I subset). It
implements real data forwarding and branch resolution, not just the
pipeline register plumbing — see "Design history" below for why that
distinction matters.

## Pipeline Stages

### 1. Instruction Fetch (IF)
- `imem_addr` is driven directly by a real PC register (`pc_reg`)
- PC advances by 4 each cycle unless stalled (holds) or a branch just
  resolved (redirects to the branch target)

### 2. Instruction Decode (ID)
- Decodes opcode/funct3/funct7, selects the correct immediate format
  (I/S/B) based on opcode
- Reads `rs1`/`rs2` from the register file, with a same-cycle
  write-then-read bypass (see "Register File" below)
- Computes `load_use_stall` (see "Hazard Handling")

### 3. Execute (EX)
- Selects ALU operands via the forwarding muxes (see "Forwarding")
- Runs the ALU (add/sub/and/or/xor/shift)
- For branches, subtracts `rs1 - rs2` and checks the ALU's zero flag
  against `funct3` to determine `BEQ`/`BNE`
- Computes `branch_target = id_ex_pc + id_ex_imm`

### 4. Memory (MEM)
- `dmem_addr`/`dmem_wdata`/`dmem_we` driven from the EX/MEM register
- Store data (`ex_mem_rs2_data`) is latched from the *forwarded*
  value, not the raw ID-stage register read — otherwise a store whose
  source register was just computed by the immediately preceding
  instruction would write stale data

### 5. Write Back (WB)
- Selects between `mem_wb_alu_result` and `mem_wb_load_data` based on
  `mem_wb_mem_to_reg`, writes to the register file

## Register File
Reads are combinational, with one deliberate exception: if the
currently-retiring WB instruction is writing the same register ID is
reading this cycle, the read returns the WB value directly instead of
the (stale, pre-write) register file contents. Without this, a
same-cycle write/read on the same register would silently read the
old value, since the actual register file write uses a non-blocking
assignment that doesn't take effect until after the read has already
happened combinationally.

## Forwarding
Two forwarding sources feed each ALU operand mux, checked in this
priority order:
1. **EX/MEM** — if the instruction currently in MEM will write the
   register this instruction needs, forward its ALU result directly
2. **MEM/WB** — otherwise, if the instruction currently in WB will
   write it, forward the WB write-back value

If neither matches, the operand falls back to the value the register
file supplied when this instruction was in ID.

## Hazard Handling

### Load-use stall
Forwarding alone can't fix a load immediately followed by a dependent
instruction — the loaded value isn't available until the load reaches
MEM, one stage later than forwarding could reach. `load_use_stall`
checks whether the instruction currently in EX (`id_ex`) is a load
whose destination matches either source register of the instruction
currently in ID. If so, the pipeline holds the PC and IF/ID for one
cycle and inserts a bubble into ID/EX, then proceeds normally.

### Branch resolution and flush
Branches resolve in EX, not ID or IF, because resolving them requires
the ALU (to compare `rs1`/`rs2`) and the ALU only exists in EX. By the
time a branch reaches EX, the pipeline has already fetched exactly one
more instruction past it into IF/ID (the one immediately following the
branch in program order) — it has *not* yet fetched a second one,
because the PC only advances one instruction per cycle and hasn't
reached the branch's fall-through target yet when the branch is
sitting in EX. So a taken branch only needs to squash that one
already-fetched instruction (by forcing IF/ID to a NOP) and redirect
the PC to the branch target — the instruction that would have been
fetched next simply gets fetched correctly from the new PC instead.

## Design history: why this needed a rewrite, not a patch

The earlier version of this design had several problems that weren't
independent bugs so much as one underlying issue: the control logic
was never actually implemented, just scaffolded with `TODO` comments.
Specifically:
- `imem_addr` was hardcoded to `32'd0` — the CPU could never fetch a
  second instruction
- The ALU's second operand was hardcoded to the immediate value,
  meaning register-register instructions like `ADD rd, rs1, rs2`
  couldn't work even in principle, regardless of the PC bug
- The ALU operation was hardcoded to always add
- `stall` and `load_use_stall` were declared but never driven by any
  logic
- The design referenced `RESET_VECTOR` and `mem_wb_mem_to_reg` without
  ever declaring either — it did not compile

Because none of this was reachable (the PC bug alone prevented any
instruction past the first from ever executing), none of it could have
been caught by running the testbench, which is exactly why it went
unnoticed. Fixing this meant implementing the missing control logic
from scratch — the PC, decode, forwarding, and branch resolution
described above — rather than patching individual lines.

## Known Limitations
- `LUI`/`AUIPC`/`JAL`/`JALR` are not implemented (decoded as harmless
  no-ops — they don't corrupt other instructions, but produce no
  useful result of their own)
- No `SLT`/`SLTU`/`SLTI` (comparison-and-set instructions)
- Only word-width loads/stores (`LW`/`SW`) — no byte/halfword variants
- No branch prediction — every branch stalls the fetch of its
  fall-through/target until it resolves in EX (a 1-instruction bubble
  cost per taken branch, described above)
- Memory is a flat array in the testbench, not a real cache/memory
  hierarchy

# Picosrv32 Architecture

## Overview
Picosrv32 is an educational 5-stage pipelined RISC-V CPU core designed to demonstrate fundamental concepts in computer architecture and VLSI design. While it implements a simplified instruction set for clarity, it captures the essential principles of modern CPU design.

## Pipeline Stages

### 1. Instruction Fetch (IF)
- Fetches instruction from instruction memory
- Uses Program Counter (PC) to determine address
- Increments PC by 4 for sequential execution
- Handles branch redirection

### 2. Instruction Decode (ID)
- Decodes instruction fields (opcode, funct3, funct7, rs1, rs2, rd, immediate)
- Reads operands from register file
- Generates immediate values for I-type, S-type, B-type, U-type, J-type instructions
- Detects hazards and inserts stalls when necessary

### 3. Execute (EX)
- Performs ALU operations (arithmetic, logical, shift)
- Calculates branch targets
- Computes memory addresses for load/store instructions
- Forwards results from later stages to avoid stalls

### 4. Memory (MEM)
- Reads from or writes to data memory
- Handles load/store instructions
- Passes through ALU results for register-register operations

### 5. Write Back (WB)
- Writes results back to register file
- Chooses between ALU result and load data based on instruction type

## Instruction Set (Supported Subset)

### Register-Immediate Instructions
- `ADDI rd, rs1, imm`: rd = rs1 + sign_extended(imm)

### Register-Register Instructions  
- `ADD rd, rs1, rs2`: rd = rs1 + rs2
- `SUB rd, rs1, rs2`: rd = rs1 - rs2
- `AND rd, rs1, rs2`: rd = rs1 & rs2
- `OR rd, rs1, rs2`: rd = rs1 | rs2
- `XOR rd, rs1, rs2`: rd = rs1 ^ rs2
- `SLL rd, rs1, rs2`: rd = rs1 << rs2(4:0)
- `SRL rd, rs1, rs2`: rd = rs1 >> rs2(4:0) (logical)
- `SRA rd, rs1, rs2`: rd = rs1 >> rs2(4:0) (arithmetic)

## Hazard Handling
The current implementation includes basic stall insertion for load-use hazards:
- When an instruction in EX stage is a load, and the next instruction in ID stage needs the loaded result
- The pipeline stalls for one cycle to allow the load to complete

## Memory Interface
- Separate instruction and data memory (Harvard architecture)
- Word-addressable for simplicity in this educational version
- Byte enables would be added for full byte/half-word support

## Clock Frequency
The maximum clock frequency is determined by the critical path, which is typically:
- Register file read → ALU operation → Register file write
- Or: PC increment → Instruction memory read → Instruction decode

## Performance Metrics
- **Ideal CPI (Cycles Per Instruction)**: 1.0 (perfect pipelining)
- **Actual CPI**: >1.0 due to stalls from hazards, branches, memory delays
- **Throughput**: Instructions per second = Clock Frequency / Actual CPI
- **Area**: Primarily determined by register file size and pipeline register count

## Design Trade-offs Made for Education
1. **Simplified Instruction Set**: Focuses on core concepts rather than completeness
2. **Ideal Memory Assumption**: Assumes single-cycle memory access (would add wait states in reality)
3. **Basic Hazard Detection**: Only handles load-use stalls (would add more hazard types in reality)
4. **Simplified ALU**: Limited operations for clarity
5. **No Forwarding**: Relies on stalls rather than forwarding for simplicity in this version

## Future Work
To make this a more complete CPU core, consider adding:
1. Complete RV32I instruction set
2. Proper forwarding unit to eliminate stalls
3. Branch prediction (static/dynamic)
4. Cache memory hierarchy
5. Memory management unit (MMU)
6. Privilege levels and trap handling
7. Performance monitoring counters
8. Debug interface (JTAG)
9. Integration with realistic memory models
10. Bootloader and simple monitor program

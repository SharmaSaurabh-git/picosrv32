# Picosrv32: A Pipelined RISC-V CPU Core

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![HDL: SystemVerilog](https://img.shields.io/badge/HDL-SystemVerilog-blue.svg)](https://en.wikipedia.org/wiki/SystemVerilog)
[![Simulator: Verilator](https://img.shields.io/badge/Simulator-Verilator-green.svg)](https://verilator.org/)
[![GitHub Stars](https://img.shields.io/github/stars/SharmaSaurabh-git/picosrv32?style=social)](https://github.com/SharmaSaurabh-git/picosrv32/stargazers)

A 5-stage pipelined RISC-V CPU core implementing a subset of the RV32I base integer instruction set. This project demonstrates computer architecture and VLSI design skills, showing understanding of pipelining, hazard detection, forwarding, and instruction set architecture - fundamental skills for CPU designers at companies like Intel, AMD, ARM, Apple, NVIDIA, and RISC-V International members.

## Features
- 5-stage classic RISC pipeline: Instruction Fetch (IF), Instruction Decode (ID), Execute (EX), Memory (MEM), Write Back (WB)
- Pipelined execution with basic hazard handling
- Register file with read/write ports
- Simple ALU supporting ADD, SUB, AND, OR, XOR, shift operations
- Basic instruction memory and data memory interfaces
- Verilog/SystemVerilog implementation
- Testbench with simple assembly program
- Waveform generation for GTKWave visualization

## Supported Instructions (Demo Subset)
- **Register-Immediate**: ADDI (add immediate)
- **Register-Register**: ADD (add registers)
- **Memory Operations**: Conceptual framework for LOAD/STORE
- **Control Flow**: Framework for BRANCH and JUMP

## Why This Matters
CPU design is at the heart of computing. Understanding pipelining, hazards, and instruction set architecture is essential for:
- CPU Architects (Intel, AMD, ARM, Apple, Qualcomm)
- SoC Designers (all semiconductor companies)
- Embedded Systems Engineers
- Computer Architects
- Performance Analysts

## Repository Structure
```
picosrv32/
├── rtl/                 # Register Transfer Level (Verilog/SystemVerilog)
│   └── picosrv32.sv     # Top-level CPU and ALU
├── tb/                  # Testbenches
│   └── tb_picosrv32.sv  # Testbench with test program
├── doc/                 # Documentation
│   └── architecture.md  # Detailed explanation
├── sim/                 # Simulation outputs
└── README.md
```

## Getting Started
1. Clone repository: `git clone https://github.com/SharmaSaurabh-git/picosrv32.git`
2. Install Verilator: `sudo apt-get install verilator` (or use your preferred simulator)
3. Simulate: `make sim`
4. View waveform: `gtkwave picosrv32.vcd`

## Example Output
The testbench runs a simple program:
```
addi x1, x0, 5   // x1 = 5
addi x2, x0, 3   // x2 = 3
add  x3, x1, x2  // x3 = x1 + x2 = 8
```
You can verify in the waveform that:
- x1 reaches 5
- x2 reaches 3  
- x3 reaches 8

## Pipeline Stages Explained
1. **IF (Instruction Fetch)**: Fetch instruction from memory
2. **ID (Instruction Decode)**: Decode instruction, read registers
3. **EX (Execute)**: Perform ALU operation or calculate address
4. **MEM (Memory)**: Access memory (for load/store)
5. **WB (Write Back)**: Write result back to register file

## Key Learning Points
- **Pipelining**: How instructions overlap in execution for better throughput
- **Hazards**: Structural, data, and control hazards that can cause stalls
- **Forwarding**: Bypassing results to avoid stalls
- **Control Logic**: How the CPU decides what to do each cycle
- **Memory Interface**: How CPUs interact with memory systems

## Future Enhancements
- Complete RV32I instruction set
- Proper hazard detection and forwarding unit
- Branch prediction
- Cache memory hierarchy (L1 I/D cache)
- Privilege levels and memory protection
- Performance counters
- Debug interface
- Integration with real memory models
- Bootloader and simple OS support

## License
MIT

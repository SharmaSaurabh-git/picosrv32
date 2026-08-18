`timescale 1ns / 1ps
//==========================================================================
//  Testbench for Picosrv32
//==========================================================================
`include "picosrv32.sv"

module tb_picosrv32;

    // Clock and reset
    reg clk;
    reg rst_n;
    
    // Memory interface
    wire [31:0] imem_addr;
    reg  [31:0] imem_rdata;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire        dmem_we;
    wire [31:0] dmem_rdata;
    
    // Instruction memory (ROM)
    reg [31:0] imem [0:63];  // 64 instructions
    
    // Data memory (RAM)
    reg [31:0] dmem [0:63];  // 64 words
    
    // Instantiate DUT
    picosrv32 cpu (
        .clk(clk),
        .rst_n(rst_n),
        .imem_addr(imem_addr),
        .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_we(dmem_we),
        .dmem_rdata(dmem_rdata)
    );
    
    // Memory connections
    assign imem_rdata = imem[imem_addr[31:2]];
    assign dmem_rdata = dmem[dmem_addr[31:2]];
    
    // Data memory write
    always @(posedge clk) begin
        if (dmem_we) begin
            dmem[dmem_addr[31:2]] <= dmem_wdata;
        end
    end
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100 MHz
    end
    
    // Reset
    initial begin
        rst_n = 0;
        #20;
        rst_n = 1;
    end
    
    // Initialize memory with a simple test program
    initial begin
        // Initialize memories to zero
        integer i;
        for (i = 0; i < 64; i = i + 1) begin
            imem[i] = 32'd0;
            dmem[i] = 32'd0;
        end
        
        // Simple test program: addi x1, x0, 5; addi x2, x0, 3; add x3, x1, x2
        // Machine code for:
        // 0x00500293 = addi x1, x0, 5
        // 0x00308293 = addi x2, x0, 3  
        // 0x002282b3 = add x3, x1, x2
        imem[0] = 32'h00500293;
        imem[1] = 32'h00308293;
        imem[2] = 32'h002282b3;
        imem[3] = 32'h00000073;  // ebreak (to stop simulation)
        
        // Fill rest with nop
        for (i = 4; i < 64; i = i + 1) begin
            imem[i] = 32'h00000013;  // nop
        end
    end
    
    // Run simulation for a fixed time
    initial begin
        #200;
        $display("Simulation finished.");
        $finish;
    end
    
    // Optional: dump waveforms
    initial begin
        $dumpfile("picosrv32.vcd");
        $dumpvars(0, tb_picosrv32);
    end

endmodule

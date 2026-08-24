`timescale 1ns / 1ps
//==========================================================================
//  Self-checking testbench for picosrv32.
//
//  Program exercises: back-to-back ALU dependencies (EX/MEM and MEM/WB
//  forwarding), a store/load pair, a load-use hazard (stall), and two
//  taken branches (BEQ, BNE) with squashed wrong-path instructions.
//
//  Compile alongside rtl/picosrv32.sv as a separate source, not via
//  `include:
//    iverilog -g2012 -o sim_out rtl/picosrv32.sv tb/tb_picosrv32.sv
//
//  Machine code below was assembled and independently decoded/verified
//  with a small Python script -- see doc/architecture.md for the
//  assembly-language listing this corresponds to.
//==========================================================================

module tb_picosrv32;

    reg clk;
    reg rst_n;

    wire [31:0] imem_addr;
    reg  [31:0] imem_rdata;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire        dmem_we;
    reg  [31:0] dmem_rdata;

    reg [31:0] imem [0:63];
    reg [31:0] dmem [0:63];

    integer errors;

    picosrv32 #(.RESET_VECTOR(32'h0)) cpu (
        .clk(clk),
        .rst_n(rst_n),
        .imem_addr(imem_addr),
        .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_we(dmem_we),
        .dmem_rdata(dmem_rdata)
    );

    always @(*) begin
        imem_rdata = imem[imem_addr[31:2]];
    end

    always @(*) begin
        dmem_rdata = dmem[dmem_addr[31:2]];
    end

    always @(posedge clk) begin
        if (dmem_we) begin
            dmem[dmem_addr[31:2]] <= dmem_wdata;
        end
    end

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    integer mi;

    initial begin
        errors = 0;

        for (mi = 0; mi < 64; mi = mi + 1) begin
            imem[mi] = 32'h0000_0013; // nop (addi x0,x0,0)
            dmem[mi] = 32'd0;
        end

        // Assembly:
        //  0: addi x1, x0, 5
        //  1: addi x2, x0, 3
        //  2: add  x3, x1, x2      -> x3=8
        //  3: sub  x4, x3, x1      -> x4=3   (needs EX/MEM forward of x3)
        //  4: add  x5, x4, x4      -> x5=6   (needs forward of x4)
        //  5: addi x6, x0, 100
        //  6: sw   x6, 0(x0)       -> mem[0]=100
        //  7: lw   x7, 0(x0)       -> x7=100
        //  8: add  x8, x7, x7      -> x8=200 (load-use hazard: stall then forward)
        //  9: addi x9, x0, 1
        // 10: beq  x9, x9, 8       -> taken, skip instr 11
        // 11: addi x10, x0, 999    -> SHOULD NOT EXECUTE
        // 12: addi x11, x0, 42     -> branch target
        // 13: bne  x1, x2, 8       -> taken (5 != 3), skip instr 14
        // 14: addi x12, x0, 888    -> SHOULD NOT EXECUTE
        // 15: addi x13, x0, 55     -> branch target
        imem[0]  = 32'h00500093;
        imem[1]  = 32'h00300113;
        imem[2]  = 32'h002081b3;
        imem[3]  = 32'h40118233;
        imem[4]  = 32'h004202b3;
        imem[5]  = 32'h06400313;
        imem[6]  = 32'h00602023;
        imem[7]  = 32'h00002383;
        imem[8]  = 32'h00738433;
        imem[9]  = 32'h00100493;
        imem[10] = 32'h00948463;
        imem[11] = 32'h3e700513;
        imem[12] = 32'h02a00593;
        imem[13] = 32'h00209463;
        imem[14] = 32'h37800613;
        imem[15] = 32'h03700693;

        rst_n = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;

        // Enough cycles for the program (16 instructions) plus pipeline
        // fill, one load-use stall bubble, and two branch-flush bubbles.
        repeat (40) @(posedge clk);

        $display("\n=== Register File Check ===");
        if (cpu.reg_file[1] !== 5) begin errors=errors+1; $display("ERROR: x1 expected 5, got %0d", cpu.reg_file[1]); end
        else $display("x1 (addi) = %0d (OK)", cpu.reg_file[1]);

        if (cpu.reg_file[2] !== 3) begin errors=errors+1; $display("ERROR: x2 expected 3, got %0d", cpu.reg_file[2]); end
        else $display("x2 (addi) = %0d (OK)", cpu.reg_file[2]);

        if (cpu.reg_file[3] !== 8) begin errors=errors+1; $display("ERROR: x3 expected 8, got %0d", cpu.reg_file[3]); end
        else $display("x3 (add, no hazard) = %0d (OK)", cpu.reg_file[3]);

        if (cpu.reg_file[4] !== 3) begin errors=errors+1; $display("ERROR: x4 expected 3, got %0d", cpu.reg_file[4]); end
        else $display("x4 (sub, EX/MEM forward) = %0d (OK)", cpu.reg_file[4]);

        if (cpu.reg_file[5] !== 6) begin errors=errors+1; $display("ERROR: x5 expected 6, got %0d", cpu.reg_file[5]); end
        else $display("x5 (add, forward) = %0d (OK)", cpu.reg_file[5]);

        if (cpu.reg_file[6] !== 100) begin errors=errors+1; $display("ERROR: x6 expected 100, got %0d", cpu.reg_file[6]); end
        else $display("x6 (addi) = %0d (OK)", cpu.reg_file[6]);

        if (cpu.reg_file[7] !== 100) begin errors=errors+1; $display("ERROR: x7 expected 100, got %0d", cpu.reg_file[7]); end
        else $display("x7 (lw) = %0d (OK)", cpu.reg_file[7]);

        if (cpu.reg_file[8] !== 200) begin errors=errors+1; $display("ERROR: x8 expected 200, got %0d", cpu.reg_file[8]); end
        else $display("x8 (add, load-use stall + forward) = %0d (OK)", cpu.reg_file[8]);

        if (cpu.reg_file[9] !== 1) begin errors=errors+1; $display("ERROR: x9 expected 1, got %0d", cpu.reg_file[9]); end
        else $display("x9 (addi) = %0d (OK)", cpu.reg_file[9]);

        if (cpu.reg_file[10] !== 0) begin errors=errors+1; $display("ERROR: x10 expected 0 (should be squashed), got %0d", cpu.reg_file[10]); end
        else $display("x10 (squashed by taken BEQ) = %0d (OK)", cpu.reg_file[10]);

        if (cpu.reg_file[11] !== 42) begin errors=errors+1; $display("ERROR: x11 expected 42, got %0d", cpu.reg_file[11]); end
        else $display("x11 (BEQ branch target) = %0d (OK)", cpu.reg_file[11]);

        if (cpu.reg_file[12] !== 0) begin errors=errors+1; $display("ERROR: x12 expected 0 (should be squashed), got %0d", cpu.reg_file[12]); end
        else $display("x12 (squashed by taken BNE) = %0d (OK)", cpu.reg_file[12]);

        if (cpu.reg_file[13] !== 55) begin errors=errors+1; $display("ERROR: x13 expected 55, got %0d", cpu.reg_file[13]); end
        else $display("x13 (BNE branch target) = %0d (OK)", cpu.reg_file[13]);

        $display("\n=== Data Memory Check ===");
        if (dmem[0] !== 100) begin errors=errors+1; $display("ERROR: mem[0] expected 100, got %0d", dmem[0]); end
        else $display("mem[0] (sw x6,0(x0)) = %0d (OK)", dmem[0]);

        if (errors == 0)
            $display("\nAll tests PASSED.");
        else
            $display("\n%0d MISMATCH(ES) -- see errors above.", errors);

        $finish;
    end

    initial begin
        $dumpfile("picosrv32.vcd");
        $dumpvars(0, tb_picosrv32);
    end

endmodule

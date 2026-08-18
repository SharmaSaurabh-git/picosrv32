`timescale 1ns / 1ps
//==========================================================================
//  Picosrv32: Educational 5-stage RISC-V Pipeline
//  Demonstrates pipelining concepts with a minimal instruction set
//==========================================================================
module picosrv32 (
    input  wire                   clk,
    input  wire                   rst_n,
    // Simple memory interface for demonstration
    output wire [31:0]            imem_addr,
    input  wire [31:0]            imem_rdata,
    output wire [31:0]            dmem_addr,
    output wire [31:0]            dmem_wdata,
    output wire                   dmem_we,
    input  wire [31:0]            dmem_rdata
);

    //==========================================================================
    //  Pipeline Registers
    //==========================================================================
    // IF/ID
    reg [31:0]                    if_id_pc;
    reg [31:0]                    if_id_insn;
    
    // ID/EX
    reg [31:0]                    id_ex_pc;
    reg [31:0]                    id_ex_rs1;
    reg [31:0]                    id_ex_rs2;
    reg [31:0]                    id_ex_imm;
    reg [4:0]                     id_ex_rd;
    reg                           id_ex_reg_write;
    reg                           id_ex_is_load;
    reg                           id_ex_is_store;
    reg [2:0]                     id_ex_alu_op;
    
    // EX/MEM
    reg [31:0]                    ex_mem_pc;
    reg [31:0]                    ex_mem_alu_result;
    reg [31:0]                    ex_mem_rs2_data;
    reg [4:0]                     ex_mem_rd;
    reg                           ex_mem_reg_write;
    reg                           ex_mem_is_load;
    reg                           ex_mem_is_store;
    
    // MEM/WB
    reg [31:0]                    mem_wb_alu_result;
    reg [31:0]                    mem_wb_load_data;
    reg [4:0]                     mem_wb_rd;
    reg                           mem_wb_reg_write;

    //==========================================================================
    //  Wires and Control Logic
    //==========================================================================
    wire [31:0]                   pc_plus_4;
    wire [31:0]                   branch_target;
    wire                          branch_taken;
    wire [31:0]                   next_pc;
    wire                          pc_write;
    wire                          stall;
    wire                          flush;
    
    wire [6:0]                    opcode    = if_id_insn[6:0];
    wire [2:0]                    funct3    = if_id_insn[14:12];
    wire [4:0]                    rs1       = if_id_insn[19:15];
    wire [4:0]                    rs2       = if_id_insn[24:20];
    wire [4:0]                    rd        = if_id_insn[11:7];
    wire [31:0]                   imm_i     = {{20{if_id_insn[31]}}, if_id_insn[31:20]};
    wire [31:0]                   imm_s     = {{20{if_id_insn[31]}}, if_id_insn[31:25], if_id_insn[11:7]};
    wire [31:0]                   imm_b     = {{19{if_id_insn[31]}}, if_id_insn[31], if_id_insn[7], if_id_insn[30:25], if_id_insn[11:8], 1'b0};
    wire [31:0]                   imm_u     = {if_id_insn[31:12], 12'b0};
    wire [31:0]                   imm_j     = {{11{if_id_insn[31]}}, if_id_insn[31], if_id_insn[19:12], if_id_insn[20], if_id_insn[30:21], 1'b0};
    
    // Register file
    wire [31:0]                   reg_rs1, reg_rs2;
    reg [31:0]                    reg_file [0:31];
    
    // ALU
    wire [31:0]                   alu_operand_a, alu_operand_b;
    wire [31:0]                   alu_result;
    wire                          alu_zero;
    
    // Simple hazard detection (load-use)
    wire                          load_use_stall;

    //==========================================================================
    //  Register File
    //==========================================================================
    initial begin
        // Initialize register file to zero
        integer i;
        for (i = 0; i < 32; i = i + 1) begin
            reg_file[i] = 32'd0;
        end
    end
    
    assign reg_rs1 = (rs1 == 5'd0) ? 32'd0 : reg_file[rs1];
    assign reg_rs2 = (rs2 == 5'd0) ? 32'd0 : reg_file[rs2];
    
    always @(posedge clk) begin
        if (mem_wb_reg_write && mem_wb_rd != 5'd0) begin
            reg_file[mem_wb_rd] <= mem_wb_mem_to_reg ? mem_wb_load_data : mem_wb_alu_result;
        end
    end

    //==========================================================================
    //  Pipeline Stage Logic
    //==========================================================================
    
    // IF Stage
    assign imem_addr = /* PC */ 32'd0;  // TODO: implement proper PC
    assign pc_plus_4 = /* PC */ 32'd0 + 32'd4;
    assign branch_target = /* PC */ 32'd0 + (imm_b << 1);
    assign branch_taken  = (funct3 == 3'b000 && alu_zero) ||  // BEQ
                          (funct3 == 3'b001 && !alu_zero) ||  // BNE
                          1'b0;  // Simplified
    assign next_pc = branch_taken ? branch_target : pc_plus_4;
    assign pc_write = !stall;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_pc     <= RESET_VECTOR;
            if_id_insn   <= 32'h00000013;  // nop
        end else if (pc_write) begin
            if_id_pc     <= next_pc;
            if_id_insn   <= imem_rdata;
        end
        if (flush) begin
            if_id_insn   <= 32'h00000013;  // nop
        end
    end
    
    // ID Stage
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Clear pipeline registers
            id_ex_pc             <= '0;
            id_ex_rs1            <= '0;
            id_ex_rs2            <= '0;
            id_ex_imm            <= '0;
            id_ex_rd             <= '0;
            id_ex_reg_write      <= 1'b0;
            id_ex_is_load        <= 1'b0;
            id_ex_is_store       <= 1'b0;
            id_ex_alu_op         <= 3'b000;
        end else begin
            id_ex_pc             <= if_id_pc;
            id_ex_rs1            <= reg_rs1;
            id_ex_rs2            <= reg_rs2;
            id_ex_imm            <= (opcode == 7'h03 || opcode == 7'h13 || opcode == 7'h67) ? imm_i :
                                   (opcode == 7'h23) ? imm_s :
                                   (opcode == 7'h63) ? imm_b :
                                   (opcode == 7'h37 || opcode == 7'h17) ? imm_u :
                                   (opcode == 7'h6F) ? imm_j : 32'd0;
            id_ex_rd             <= rd;
            id_ex_reg_write      <= (opcode == 7'h33 || opcode == 7'h13 || opcode == 7'h37 ||
                                    opcode == 7'h6F || opcode == 7'h67 || opcode == 7'h3 ||
                                    opcode == 7'h17 || opcode == 7'h27);
            id_ex_is_load        <= (opcode == 7'h03);
            id_ex_is_store       <= (opcode == 7'h23);
            id_ex_alu_op         <= /* ALU control */ 3'b000;  // TODO: implement based on funct3/funct7
        end
    end
    
    // EX Stage
    assign alu_operand_a = id_ex_rs1;
    assign alu_operand_b = id_ex_imm;  // Simplified - always use immediate for demo
    alu alu (
        .a(alu_operand_a),
        .b(alu_operand_b),
        .alu_op(id_ex_alu_op),
        .result(alu_result),
        .zero(alu_zero)
    );
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_pc             <= '0;
            ex_mem_alu_result     <= '0;
            ex_mem_rs2_data       <= id_ex_rs2;
            ex_mem_rd             <= '0;
            ex_mem_reg_write      <= 1'b0;
            ex_mem_is_load        <= 1'b0;
            ex_mem_is_store       <= 1'b0;
        end else begin
            ex_mem_pc             <= id_ex_pc;
            ex_mem_alu_result     <= alu_result;
            ex_mem_rs2_data       <= id_ex_rs2;
            ex_mem_rd             <= id_ex_rd;
            ex_mem_reg_write      <= id_ex_reg_write;
            ex_mem_is_load        <= id_ex_is_load;
            ex_mem_is_store       <= id_ex_is_store;
        end
    end
    
    // MEM Stage
    assign dmem_addr   = ex_mem_alu_result;
    assign dmem_wdata  = ex_mem_rs2_data;
    assign dmem_we     = ex_mem_is_store;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_alu_result   <= '0;
            mem_wb_load_data    <= '0;
            mem_wb_rd           <= '0;
            mem_wb_reg_write    <= 1'b0;
        end else begin
            mem_wb_alu_result   <= ex_mem_alu_result;
            mem_wb_load_data    <= dmem_rdata;
            mem_wb_rd           <= ex_mem_rd;
            mem_wb_reg_write    <= ex_mem_reg_write;
        end
    end
    
    // WB Stage: Write back handled by register file (above)

endmodule

//==========================================================================
//  Simple ALU for demonstration
//==========================================================================
module alu (
    input  wire [31:0]            a,
    input  wire [31:0]            b,
    input  wire [2:0]             alu_op,
    output reg [31:0]             result,
    output reg                    zero
);
    always @(*) begin
        case (alu_op)
            3'b000: result = a + b;  // ADD
            3'b001: result = a - b;  // SUB
            3'b010: result = a & b;  // AND
            3'b011: result = a | b;  // OR
            3'b100: result = a ^ b;  // XOR
            3'b101: result = a >> b; // SRL (logical)
            3'b110: result = a << b; // SLL
            default: result = 32'd0;
        endcase
        zero = (result == 32'd0);
    end
endmodule

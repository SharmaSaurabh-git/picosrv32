`timescale 1ns / 1ps
//==========================================================================
//  Picosrv32: Educational 5-stage RISC-V (RV32I subset) Pipeline
//
//  Supported: R-type ALU (ADD/SUB/AND/OR/XOR/SLL/SRL/SRA), I-type ALU
//  (ADDI/ANDI/ORI/XORI/SLLI/SRLI/SRAI), LW, SW, BEQ/BNE.
//  Not implemented: LUI, AUIPC, JAL, JALR, SLT/SLTU/SLTI, other loads/
//  stores (LB/LH/etc.), FENCE, ECALL/EBREAK (decoded as harmless no-ops,
//  not functional). See doc/architecture.md for the full scope note.
//
//  Hazard handling: full EX/MEM and MEM/WB forwarding to the ALU, a
//  same-cycle write-then-read bypass in the register file, a one-cycle
//  stall for load-use hazards, and branch resolution in EX with a
//  2-instruction flush on taken branches.
//==========================================================================
module picosrv32 #(
    parameter RESET_VECTOR = 32'h0000_0000
) (
    input  wire                   clk,
    input  wire                   rst_n,
    output wire [31:0]            imem_addr,
    input  wire [31:0]            imem_rdata,
    output wire [31:0]            dmem_addr,
    output wire [31:0]            dmem_wdata,
    output wire                   dmem_we,
    input  wire [31:0]            dmem_rdata
);

    localparam [31:0] NOP = 32'h0000_0013; // addi x0, x0, 0

    localparam [2:0] ALU_ADD=3'b000, ALU_SUB=3'b001, ALU_AND=3'b010,
                      ALU_OR =3'b011, ALU_XOR=3'b100, ALU_SRL=3'b101,
                      ALU_SLL=3'b110, ALU_SRA=3'b111;

    localparam [6:0] OP_R      = 7'b0110011;
    localparam [6:0] OP_I_ALU  = 7'b0010011;
    localparam [6:0] OP_LOAD   = 7'b0000011;
    localparam [6:0] OP_STORE  = 7'b0100011;
    localparam [6:0] OP_BRANCH = 7'b1100011;

    //======================================================================
    //  Program Counter
    //======================================================================
    reg  [31:0] pc_reg;
    wire [31:0] pc_plus_4 = pc_reg + 32'd4;

    //======================================================================
    //  Pipeline Registers
    //======================================================================
    // IF/ID
    reg [31:0] if_id_pc;
    reg [31:0] if_id_insn;

    // ID/EX
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_rs1;
    reg [31:0] id_ex_rs2;
    reg [31:0] id_ex_imm;
    reg [4:0]  id_ex_rs1_addr;
    reg [4:0]  id_ex_rs2_addr;
    reg [4:0]  id_ex_rd;
    reg        id_ex_reg_write;
    reg        id_ex_is_load;
    reg        id_ex_is_store;
    reg        id_ex_is_branch;
    reg        id_ex_alu_use_rs2;   // 1 = R-type/branch (operand B = rs2), 0 = imm
    reg [2:0]  id_ex_alu_op;
    reg [2:0]  id_ex_funct3;

    // EX/MEM
    reg [31:0] ex_mem_pc;
    reg [31:0] ex_mem_alu_result;
    reg [31:0] ex_mem_rs2_data;
    reg [4:0]  ex_mem_rd;
    reg        ex_mem_reg_write;
    reg        ex_mem_is_load;
    reg        ex_mem_is_store;

    // MEM/WB
    reg [31:0] mem_wb_alu_result;
    reg [31:0] mem_wb_load_data;
    reg [4:0]  mem_wb_rd;
    reg        mem_wb_reg_write;
    reg        mem_wb_mem_to_reg;

    //======================================================================
    //  Instruction Decode (combinational, on if_id_insn)
    //======================================================================
    wire [6:0] opcode = if_id_insn[6:0];
    wire [2:0] funct3 = if_id_insn[14:12];
    wire       funct7_bit5 = if_id_insn[30];
    wire [4:0] rs1     = if_id_insn[19:15];
    wire [4:0] rs2     = if_id_insn[24:20];
    wire [4:0] rd      = if_id_insn[11:7];

    wire [31:0] imm_i = {{20{if_id_insn[31]}}, if_id_insn[31:20]};
    wire [31:0] imm_s = {{20{if_id_insn[31]}}, if_id_insn[31:25], if_id_insn[11:7]};
    wire [31:0] imm_b = {{19{if_id_insn[31]}}, if_id_insn[31], if_id_insn[7],
                          if_id_insn[30:25], if_id_insn[11:8], 1'b0};

    wire [31:0] imm_sel = (opcode == OP_STORE)  ? imm_s :
                          (opcode == OP_BRANCH) ? imm_b :
                                                    imm_i; // loads + I-ALU

    wire is_r_type  = (opcode == OP_R);
    wire is_i_alu   = (opcode == OP_I_ALU);
    wire is_load    = (opcode == OP_LOAD);
    wire is_store   = (opcode == OP_STORE);
    wire is_branch  = (opcode == OP_BRANCH);
    wire reg_write_d = is_r_type || is_i_alu || is_load;

    function [2:0] alu_op_decode(input [6:0] op, input [2:0] f3, input f7b5);
        begin
            if (op == OP_R || op == OP_I_ALU) begin
                case (f3)
                    3'b000:  alu_op_decode = (op == OP_R && f7b5) ? ALU_SUB : ALU_ADD;
                    3'b111:  alu_op_decode = ALU_AND;
                    3'b110:  alu_op_decode = ALU_OR;
                    3'b100:  alu_op_decode = ALU_XOR;
                    3'b101:  alu_op_decode = f7b5 ? ALU_SRA : ALU_SRL;
                    3'b001:  alu_op_decode = ALU_SLL;
                    default: alu_op_decode = ALU_ADD;
                endcase
            end else if (op == OP_BRANCH) begin
                alu_op_decode = ALU_SUB; // compare via subtract, check zero
            end else begin
                alu_op_decode = ALU_ADD; // loads/stores: address = base + offset
            end
        end
    endfunction

    //======================================================================
    //  Register File (write-first: same-cycle WB write is visible to ID read)
    //======================================================================
    reg  [31:0] reg_file [0:31];
    wire [31:0] wb_write_data = mem_wb_mem_to_reg ? mem_wb_load_data : mem_wb_alu_result;

    wire [31:0] reg_rs1 = (rs1 == 5'd0) ? 32'd0 :
                          (mem_wb_reg_write && mem_wb_rd == rs1) ? wb_write_data :
                          reg_file[rs1];
    wire [31:0] reg_rs2 = (rs2 == 5'd0) ? 32'd0 :
                          (mem_wb_reg_write && mem_wb_rd == rs2) ? wb_write_data :
                          reg_file[rs2];

    integer ri;
    initial begin
        for (ri = 0; ri < 32; ri = ri + 1) reg_file[ri] = 32'd0;
    end

    always @(posedge clk) begin
        if (mem_wb_reg_write && mem_wb_rd != 5'd0) begin
            reg_file[mem_wb_rd] <= wb_write_data;
        end
    end

    //======================================================================
    //  Hazard Detection (load-use stall)
    //======================================================================
    wire load_use_stall = id_ex_is_load && (id_ex_rd != 5'd0) &&
                           ((id_ex_rd == rs1) || (id_ex_rd == rs2));
    wire stall = load_use_stall;
    wire pc_write = !stall;

    //======================================================================
    //  EX Stage: forwarding + ALU + branch resolution
    //======================================================================
    wire [31:0] fwd_a =
        (ex_mem_reg_write && ex_mem_rd != 5'd0 && ex_mem_rd == id_ex_rs1_addr) ? ex_mem_alu_result :
        (mem_wb_reg_write && mem_wb_rd != 5'd0 && mem_wb_rd == id_ex_rs1_addr) ? wb_write_data :
        id_ex_rs1;

    wire [31:0] fwd_b =
        (ex_mem_reg_write && ex_mem_rd != 5'd0 && ex_mem_rd == id_ex_rs2_addr) ? ex_mem_alu_result :
        (mem_wb_reg_write && mem_wb_rd != 5'd0 && mem_wb_rd == id_ex_rs2_addr) ? wb_write_data :
        id_ex_rs2;

    wire [31:0] alu_operand_a = fwd_a;
    wire [31:0] alu_operand_b = id_ex_alu_use_rs2 ? fwd_b : id_ex_imm;

    wire [31:0] alu_result;
    wire        alu_zero;
    alu alu_inst (
        .a(alu_operand_a),
        .b(alu_operand_b),
        .alu_op(id_ex_alu_op),
        .result(alu_result),
        .zero(alu_zero)
    );

    wire branch_taken = id_ex_is_branch &&
                         ((id_ex_funct3 == 3'b000 && alu_zero) ||   // BEQ
                          (id_ex_funct3 == 3'b001 && !alu_zero));   // BNE
    wire [31:0] branch_target = id_ex_pc + id_ex_imm;
    wire        branch_flush  = branch_taken;

    //======================================================================
    //  IF Stage
    //======================================================================
    assign imem_addr = pc_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_reg <= RESET_VECTOR;
        end else if (branch_flush) begin
            pc_reg <= branch_target;
        end else if (stall) begin
            pc_reg <= pc_reg;
        end else begin
            pc_reg <= pc_plus_4;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_pc   <= RESET_VECTOR;
            if_id_insn <= NOP;
        end else if (branch_flush) begin
            if_id_insn <= NOP; // squash: wrong-path instruction just fetched
        end else if (stall) begin
            // hold: re-decode the same instruction next cycle
        end else begin
            if_id_pc   <= pc_reg;
            if_id_insn <= imem_rdata;
        end
    end

    //======================================================================
    //  ID/EX Register (inserts a bubble on stall or branch flush)
    //======================================================================
    wire insert_bubble = stall || branch_flush;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || insert_bubble) begin
            id_ex_pc           <= '0;
            id_ex_rs1          <= '0;
            id_ex_rs2          <= '0;
            id_ex_imm          <= '0;
            id_ex_rs1_addr     <= '0;
            id_ex_rs2_addr     <= '0;
            id_ex_rd           <= '0;
            id_ex_reg_write    <= 1'b0;
            id_ex_is_load      <= 1'b0;
            id_ex_is_store     <= 1'b0;
            id_ex_is_branch    <= 1'b0;
            id_ex_alu_use_rs2  <= 1'b0;
            id_ex_alu_op       <= ALU_ADD;
            id_ex_funct3       <= 3'b000;
        end else begin
            id_ex_pc           <= if_id_pc;
            id_ex_rs1          <= reg_rs1;
            id_ex_rs2          <= reg_rs2;
            id_ex_imm          <= imm_sel;
            id_ex_rs1_addr     <= rs1;
            id_ex_rs2_addr     <= rs2;
            id_ex_rd           <= rd;
            id_ex_reg_write    <= reg_write_d;
            id_ex_is_load      <= is_load;
            id_ex_is_store     <= is_store;
            id_ex_is_branch    <= is_branch;
            id_ex_alu_use_rs2  <= is_r_type || is_branch;
            id_ex_alu_op       <= alu_op_decode(opcode, funct3, funct7_bit5);
            id_ex_funct3       <= funct3;
        end
    end

    //======================================================================
    //  EX/MEM Register
    //======================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_pc          <= '0;
            ex_mem_alu_result  <= '0;
            ex_mem_rs2_data    <= '0;
            ex_mem_rd          <= '0;
            ex_mem_reg_write   <= 1'b0;
            ex_mem_is_load     <= 1'b0;
            ex_mem_is_store    <= 1'b0;
        end else begin
            ex_mem_pc          <= id_ex_pc;
            ex_mem_alu_result  <= alu_result;
            ex_mem_rs2_data    <= fwd_b; // forwarded, so stores see fresh data too
            ex_mem_rd          <= id_ex_rd;
            ex_mem_reg_write   <= id_ex_reg_write;
            ex_mem_is_load     <= id_ex_is_load;
            ex_mem_is_store    <= id_ex_is_store;
        end
    end

    //======================================================================
    //  MEM Stage
    //======================================================================
    assign dmem_addr  = ex_mem_alu_result;
    assign dmem_wdata = ex_mem_rs2_data;
    assign dmem_we    = ex_mem_is_store;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_alu_result <= '0;
            mem_wb_load_data  <= '0;
            mem_wb_rd         <= '0;
            mem_wb_reg_write  <= 1'b0;
            mem_wb_mem_to_reg <= 1'b0;
        end else begin
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_load_data  <= dmem_rdata;
            mem_wb_rd         <= ex_mem_rd;
            mem_wb_reg_write  <= ex_mem_reg_write;
            mem_wb_mem_to_reg <= ex_mem_is_load;
        end
    end

    // WB stage: register file write handled above (write-first read logic)

endmodule

//==========================================================================
//  ALU
//==========================================================================
module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [2:0]  alu_op,
    output reg  [31:0] result,
    output reg         zero
);
    always @(*) begin
        case (alu_op)
            3'b000:  result = a + b;                          // ADD
            3'b001:  result = a - b;                          // SUB
            3'b010:  result = a & b;                          // AND
            3'b011:  result = a | b;                          // OR
            3'b100:  result = a ^ b;                          // XOR
            3'b101:  result = a >> b[4:0];                    // SRL
            3'b110:  result = a << b[4:0];                    // SLL
            3'b111:  result = $signed(a) >>> b[4:0];          // SRA
            default: result = 32'd0;
        endcase
        zero = (result == 32'd0);
    end
endmodule

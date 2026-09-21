// ============================================================
//  5-Stage Pipeline Controller
//  Maps directly to: cpu/pipeline.py
//
//  Stages: IF → ID → EX → MEM → WB
// ============================================================

`include "utils/defines.vh"

module pipeline #(
    parameter XLEN = `XLEN
)(
    input  wire             clk,
    input  wire             rst_n,

    // Instruction memory
    output wire [XLEN-1:0]  imem_addr,
    input  wire [31:0]      imem_rdata,   // instructions are 32-bit

    // Data memory
    output wire [XLEN-1:0]  dmem_addr,
    output wire [XLEN-1:0]  dmem_wdata,
    output wire             dmem_we,
    output wire             dmem_re,
    output wire [1:0]       dmem_size,
    input  wire [XLEN-1:0]  dmem_rdata,
    input  wire             dmem_ready,

    // Debug / status
    output wire [XLEN-1:0]  debug_pc,
    output wire             debug_stall
);

    // ------------------------------------------------------------
    //  Pipeline registers
    // ------------------------------------------------------------
    // IF/ID
    reg [XLEN-1:0] if_id_pc;
    reg [31:0]     if_id_inst;
    reg            if_id_valid;
    reg            if_id_pred_taken;
    reg [XLEN-1:0] if_id_pred_target;

    // ID/EX
    reg [XLEN-1:0] id_ex_pc;
    reg [XLEN-1:0] id_ex_rs1_data, id_ex_rs2_data;
    reg [XLEN-1:0] id_ex_imm;
    reg [4:0]      id_ex_rs1, id_ex_rs2, id_ex_rd;
    reg            id_ex_reg_write, id_ex_mem_read, id_ex_mem_write;
    reg            id_ex_mem_to_reg, id_ex_alu_src;
    reg            id_ex_is_branch, id_ex_is_jal, id_ex_is_jalr;
    reg            id_ex_is_muldiv;
    reg [4:0]      id_ex_alu_op;
    reg [1:0]      id_ex_mem_size;
    reg [2:0]      id_ex_funct3;
    reg            id_ex_valid;
    reg            id_ex_pred_taken;
    reg [XLEN-1:0] id_ex_pred_target;

    // EX/MEM
    reg [XLEN-1:0] ex_mem_alu_result;
    reg [XLEN-1:0] ex_mem_rs2_data;
    reg [4:0]      ex_mem_rd;
    reg            ex_mem_reg_write, ex_mem_mem_read, ex_mem_mem_write;
    reg            ex_mem_mem_to_reg;
    reg [1:0]      ex_mem_mem_size;
    reg            ex_mem_valid;

    // MEM/WB
    reg [XLEN-1:0] mem_wb_alu_result, mem_wb_mem_data;
    reg [4:0]      mem_wb_rd;
    reg            mem_wb_reg_write, mem_wb_mem_to_reg;
    reg            mem_wb_valid;

    // ------------------------------------------------------------
    //  Program Counter & control
    // ------------------------------------------------------------
    reg  [XLEN-1:0] pc;
    wire [XLEN-1:0] pc_plus4 = pc + {{(XLEN-3){1'b0}}, 3'd4};
    wire            stall;
    wire            flush_id_ex;
    wire            flush_if_id;
    wire            take_branch;
    wire [XLEN-1:0] branch_target;
    wire [XLEN-1:0] next_pc;

    assign debug_pc    = pc;
    assign debug_stall = stall;

    // ------------------------------------------------------------
    //  Frontend: Branch Predictor + BTB
    // ------------------------------------------------------------
    wire            pred_taken;
    wire            pred_valid;
    wire [XLEN-1:0] btb_target;
    wire            btb_hit;

    branch_predictor #(.ENTRIES(64), .XLEN(XLEN)) u_predictor (
        .clk          (clk),
        .rst_n        (rst_n),
        .pc           (pc),
        .predict_req  (1'b1),
        .pred_taken   (pred_taken),
        .pred_valid   (pred_valid),
        .update_en    (id_ex_valid && (id_ex_is_branch || id_ex_is_jal || id_ex_is_jalr)),
        .update_pc    (id_ex_pc),
        .actual_taken (take_branch)
    );

    btb #(.ENTRIES(64), .XLEN(XLEN)) u_btb (
        .clk           (clk),
        .rst_n         (rst_n),
        .pc            (pc),
        .lookup_en     (1'b1),
        .target        (btb_target),
        .hit           (btb_hit),
        .update_en     (id_ex_valid && take_branch),
        .update_pc     (id_ex_pc),
        .update_target (branch_target)
    );

    // Speculative next PC
    wire [XLEN-1:0] predicted_next = (pred_taken && btb_hit) ? btb_target : pc_plus4;

    // ------------------------------------------------------------
    //  IF Stage
    // ------------------------------------------------------------
    assign imem_addr = pc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc              <= {XLEN{1'b0}};
            if_id_pc        <= {XLEN{1'b0}};
            if_id_inst      <= 32'h00000013; // NOP
            if_id_valid     <= 1'b0;
            if_id_pred_taken<= 1'b0;
            if_id_pred_target <= {XLEN{1'b0}};
        end
        else if (!stall) begin
            pc <= next_pc;

            if (flush_if_id) begin
                if_id_inst       <= 32'h00000013;
                if_id_valid      <= 1'b0;
                if_id_pred_taken <= 1'b0;
            end
            else begin
                if_id_pc          <= pc;
                if_id_inst        <= imem_rdata;
                if_id_valid       <= 1'b1;
                if_id_pred_taken  <= pred_taken && btb_hit;
                if_id_pred_target <= btb_target;
            end
        end
    end

    // ------------------------------------------------------------
    //  ID Stage
    // ------------------------------------------------------------
    wire [4:0] id_rs1 = if_id_inst[19:15];
    wire [4:0] id_rs2 = if_id_inst[24:20];
    wire [4:0] id_rd  = if_id_inst[11:7];
    wire [2:0] id_funct3 = if_id_inst[14:12];

    // --------------------------------------------------------
    //  ISA layer (mirrors your three Python files)
    //    decoder.v  → pure field + immediate extraction
    //    rv32i.v    → base integer control (like rv64i.py)
    //    rv64m.v    → M-extension control (like rv64m.py)
    // --------------------------------------------------------
    wire [6:0]       id_opcode, id_funct7;
    wire [XLEN-1:0]  id_imm;
    wire             id_is_branch_op, id_is_jal_op, id_is_jalr_op;
    wire             id_is_load_op, id_is_store_op, id_is_op_imm, id_is_op;
    wire             id_is_lui, id_is_auipc;

    decoder #(.XLEN(XLEN)) u_decoder (
        .inst         (if_id_inst),
        .opcode       (id_opcode),
        .rd           (),
        .funct3       (),
        .rs1          (),
        .rs2          (),
        .funct7       (id_funct7),
        .imm_i        (),
        .imm_s        (),
        .imm_b        (),
        .imm_u        (),
        .imm_j        (),
        .imm          (id_imm),
        .is_branch_op (id_is_branch_op),
        .is_jal_op    (id_is_jal_op),
        .is_jalr_op   (id_is_jalr_op),
        .is_load_op   (id_is_load_op),
        .is_store_op  (id_is_store_op),
        .is_op_imm    (id_is_op_imm),
        .is_op        (id_is_op),
        .is_lui       (id_is_lui),
        .is_auipc     (id_is_auipc),
        .is_system    ()
    );

    // Base integer control (rv32i / rv64i)
    wire id_reg_write_i, id_mem_read, id_mem_write, id_mem_to_reg, id_alu_src;
    wire id_is_branch, id_is_jal, id_is_jalr;
    wire [4:0] id_alu_op_i;
    wire [1:0] id_mem_size;
    wire       id_valid_i;

    rv32i #(.XLEN(XLEN)) u_rv32i (
        .opcode       (id_opcode),
        .funct3       (id_funct3),
        .funct7       (id_funct7),
        .is_branch_op (id_is_branch_op),
        .is_jal_op    (id_is_jal_op),
        .is_jalr_op   (id_is_jalr_op),
        .is_load_op   (id_is_load_op),
        .is_store_op  (id_is_store_op),
        .is_op_imm    (id_is_op_imm),
        .is_op        (id_is_op),
        .is_lui       (id_is_lui),
        .is_auipc     (id_is_auipc),
        .reg_write    (id_reg_write_i),
        .mem_read     (id_mem_read),
        .mem_write    (id_mem_write),
        .mem_to_reg   (id_mem_to_reg),
        .alu_src      (id_alu_src),
        .is_branch    (id_is_branch),
        .is_jal       (id_is_jal),
        .is_jalr      (id_is_jalr),
        .is_muldiv    (),                 // always 0
        .alu_op       (id_alu_op_i),
        .mem_size     (id_mem_size),
        .valid_inst   (id_valid_i)
    );

    // M-extension control
    wire id_reg_write_m, id_is_muldiv;
    wire [4:0] id_alu_op_m;
    wire       id_valid_m;

    rv64m u_rv64m (
        .opcode     (id_opcode),
        .funct3     (id_funct3),
        .funct7     (id_funct7),
        .is_op      (id_is_op),
        .reg_write  (id_reg_write_m),
        .is_muldiv  (id_is_muldiv),
        .alu_op     (id_alu_op_m),
        .valid_inst (id_valid_m)
    );

    // Merge the two ISA units (M has priority when it claims the op)
    wire       id_reg_write = id_valid_m ? id_reg_write_m : id_reg_write_i;
    wire [4:0] id_alu_op    = id_valid_m ? id_alu_op_m    : id_alu_op_i;


    // Register file
    wire [XLEN-1:0] rf_rdata1, rf_rdata2;
    wire [XLEN-1:0] wb_wdata;

    regfile #(.XLEN(XLEN)) u_regfile (
        .clk    (clk),
        .rst_n  (rst_n),
        .we     (mem_wb_reg_write),
        .waddr  (mem_wb_rd),
        .wdata  (wb_wdata),
        .raddr1 (id_rs1),
        .raddr2 (id_rs2),
        .rdata1 (rf_rdata1),
        .rdata2 (rf_rdata2)
    );

    // Hazard unit
    hazard_unit u_hazard (
        .id_rs1      (id_rs1),
        .id_rs2      (id_rs2),
        .ex_mem_read (id_ex_mem_read),
        .ex_rd       (id_ex_rd),
        .stall       (stall),
        .flush_id_ex (flush_id_ex)
    );

    // ID/EX register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex_pc          <= {XLEN{1'b0}};
            id_ex_rs1_data    <= {XLEN{1'b0}};
            id_ex_rs2_data    <= {XLEN{1'b0}};
            id_ex_imm         <= {XLEN{1'b0}};
            id_ex_rs1         <= 5'd0;
            id_ex_rs2         <= 5'd0;
            id_ex_rd          <= 5'd0;
            id_ex_reg_write   <= 1'b0;
            id_ex_mem_read    <= 1'b0;
            id_ex_mem_write   <= 1'b0;
            id_ex_mem_to_reg  <= 1'b0;
            id_ex_alu_src     <= 1'b0;
            id_ex_is_branch   <= 1'b0;
            id_ex_is_jal      <= 1'b0;
            id_ex_is_jalr     <= 1'b0;
            id_ex_is_muldiv   <= 1'b0;
            id_ex_alu_op      <= 5'd0;
            id_ex_mem_size    <= 2'd0;
            id_ex_funct3      <= 3'd0;
            id_ex_valid       <= 1'b0;
            id_ex_pred_taken  <= 1'b0;
            id_ex_pred_target <= {XLEN{1'b0}};
        end
        else if (flush_id_ex || flush_if_id) begin
            // Insert bubble – clear all control
            id_ex_reg_write   <= 1'b0;
            id_ex_mem_read    <= 1'b0;
            id_ex_mem_write   <= 1'b0;
            id_ex_mem_to_reg  <= 1'b0;
            id_ex_alu_src     <= 1'b0;
            id_ex_is_branch   <= 1'b0;
            id_ex_is_jal      <= 1'b0;
            id_ex_is_jalr     <= 1'b0;
            id_ex_is_muldiv   <= 1'b0;
            id_ex_valid       <= 1'b0;
            id_ex_pred_taken  <= 1'b0;
        end
        else if (!stall) begin
            id_ex_pc          <= if_id_pc;
            id_ex_rs1_data    <= rf_rdata1;
            id_ex_rs2_data    <= rf_rdata2;
            id_ex_imm         <= id_imm;
            id_ex_rs1         <= id_rs1;
            id_ex_rs2         <= id_rs2;
            id_ex_rd          <= id_rd;
            id_ex_reg_write   <= id_reg_write;
            id_ex_mem_read    <= id_mem_read;
            id_ex_mem_write   <= id_mem_write;
            id_ex_mem_to_reg  <= id_mem_to_reg;
            id_ex_alu_src     <= id_alu_src;
            id_ex_is_branch   <= id_is_branch;
            id_ex_is_jal      <= id_is_jal;
            id_ex_is_jalr     <= id_is_jalr;
            id_ex_is_muldiv   <= id_is_muldiv;
            id_ex_alu_op      <= id_alu_op;
            id_ex_mem_size    <= id_mem_size;
            id_ex_funct3      <= id_funct3;
            id_ex_valid       <= if_id_valid;
            id_ex_pred_taken  <= if_id_pred_taken;
            id_ex_pred_target <= if_id_pred_target;
        end
    end

    // ------------------------------------------------------------
    //  EX Stage
    // ------------------------------------------------------------
    wire [1:0] forward_a, forward_b;
    forwarding_unit u_fwd (
        .ex_rs1        (id_ex_rs1),
        .ex_rs2        (id_ex_rs2),
        .mem_reg_write (ex_mem_reg_write),
        .mem_rd        (ex_mem_rd),
        .wb_reg_write  (mem_wb_reg_write),
        .wb_rd         (mem_wb_rd),
        .forward_a     (forward_a),
        .forward_b     (forward_b)
    );

    reg [XLEN-1:0] alu_a, alu_b_raw;
    always @(*) begin
        case (forward_a)
            2'b01:   alu_a = ex_mem_alu_result;
            2'b10:   alu_a = wb_wdata;
            default: alu_a = id_ex_rs1_data;
        endcase
        case (forward_b)
            2'b01:   alu_b_raw = ex_mem_alu_result;
            2'b10:   alu_b_raw = wb_wdata;
            default: alu_b_raw = id_ex_rs2_data;
        endcase
    end

    wire [XLEN-1:0] alu_b = id_ex_alu_src ? id_ex_imm : alu_b_raw;

    // ALU
    wire [XLEN-1:0] alu_result;
    wire            alu_zero;
    alu #(.XLEN(XLEN)) u_alu (
        .a      (alu_a),
        .b      (alu_b),
        .op     (id_ex_alu_op),
        .result (alu_result),
        .zero   (alu_zero)
    );

    // Mul/Div unit
    wire [XLEN-1:0] muldiv_result;
    muldiv #(.XLEN(XLEN)) u_muldiv (
        .a      (alu_a),
        .b      (alu_b_raw),
        .op     (id_ex_alu_op),
        .result (muldiv_result)
    );

    wire [XLEN-1:0] ex_result = id_ex_is_muldiv ? muldiv_result :
                                (id_ex_is_jal || id_ex_is_jalr) ? (id_ex_pc + {{(XLEN-3){1'b0}}, 3'd4}) :
                                alu_result;

    // Branch unit
    branch_unit #(.XLEN(XLEN)) u_branch (
        .rs1_data  (alu_a),
        .rs2_data  (alu_b_raw),
        .pc        (id_ex_pc),
        .imm       (id_ex_imm),
        .funct3    (id_ex_funct3),
        .is_branch (id_ex_is_branch),
        .is_jal    (id_ex_is_jal),
        .is_jalr   (id_ex_is_jalr),
        .taken     (take_branch),
        .target    (branch_target)
    );

    // Only honour branch decision when EX stage has a valid instruction
    wire do_take = id_ex_valid && take_branch;

    // Misprediction: predicted direction/target was wrong
    wire mispredict = id_ex_valid &&
                      ((take_branch != id_ex_pred_taken) ||
                       (take_branch && (branch_target != id_ex_pred_target)));

    // Flush IF/ID on any resolved taken branch or mispredict
    assign flush_if_id = do_take || mispredict;

    // Next PC selection (priority: resolved branch > sequential)
    assign next_pc = do_take ? branch_target : pc_plus4;

    // EX/MEM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_alu_result <= {XLEN{1'b0}};
            ex_mem_rs2_data   <= {XLEN{1'b0}};
            ex_mem_rd         <= 5'd0;
            ex_mem_reg_write  <= 1'b0;
            ex_mem_mem_read   <= 1'b0;
            ex_mem_mem_write  <= 1'b0;
            ex_mem_mem_to_reg <= 1'b0;
            ex_mem_mem_size   <= 2'd0;
            ex_mem_valid      <= 1'b0;
        end
        else begin
            ex_mem_alu_result <= ex_result;
            ex_mem_rs2_data   <= alu_b_raw;
            ex_mem_rd         <= id_ex_rd;
            ex_mem_reg_write  <= id_ex_reg_write & id_ex_valid;
            ex_mem_mem_read   <= id_ex_mem_read  & id_ex_valid;
            ex_mem_mem_write  <= id_ex_mem_write & id_ex_valid;
            ex_mem_mem_to_reg <= id_ex_mem_to_reg;
            ex_mem_mem_size   <= id_ex_mem_size;
            ex_mem_valid      <= id_ex_valid;
        end
    end

    // ------------------------------------------------------------
    //  MEM Stage
    // ------------------------------------------------------------
    assign dmem_addr  = ex_mem_alu_result;
    assign dmem_wdata = ex_mem_rs2_data;
    assign dmem_we    = ex_mem_mem_write;
    assign dmem_re    = ex_mem_mem_read;
    assign dmem_size  = ex_mem_mem_size;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_alu_result <= {XLEN{1'b0}};
            mem_wb_mem_data   <= {XLEN{1'b0}};
            mem_wb_rd         <= 5'd0;
            mem_wb_reg_write  <= 1'b0;
            mem_wb_mem_to_reg <= 1'b0;
            mem_wb_valid      <= 1'b0;
        end
        else begin
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_mem_data   <= dmem_rdata;
            mem_wb_rd         <= ex_mem_rd;
            mem_wb_reg_write  <= ex_mem_reg_write & ex_mem_valid;
            mem_wb_mem_to_reg <= ex_mem_mem_to_reg;
            mem_wb_valid      <= ex_mem_valid;
        end
    end

    // ------------------------------------------------------------
    //  WB Stage
    // ------------------------------------------------------------
    assign wb_wdata = mem_wb_mem_to_reg ? mem_wb_mem_data : mem_wb_alu_result;

endmodule

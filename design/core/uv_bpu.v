//************************************************************
// See LICENSE for license details.
//
// Module: uv_bpu
//
// Designer: Owen
//
// Description:
//      Branch Prediction Unit.
//************************************************************

`timescale 1ns / 1ps

module uv_bpu
#(
    parameter ALEN = 32,
    parameter ILEN = 32,
    parameter XLEN = 32
)
(
    input                   clk,
    input                   rst_n,
    
    // PC after reset, from system config.
    input  [ALEN-1:0]       rst_pc,

    // PC & instruction from IFU.
    input                   if2bp_vld,
    input  [ALEN-1:0]       if2bp_pc,
    input  [ILEN-1:0]       if2bp_inst,
    input                   if2bp_stall,

    // Reading from RF.
    output [4:0]            bp2rf_rd_idx,
    input  [XLEN-1:0]       bp2rf_rd_data,

    // INFO from forwarding path.
    input                   if2bp_fw_act,
    input  [4:0]            if2bp_fw_idx,

    input                   id2bp_fw_act,
    input  [4:0]            id2bp_fw_idx,

    input                   ex2bp_fw_act,
    input                   ex2bp_fw_vld,
    input  [4:0]            ex2bp_fw_idx,
    input  [XLEN-1:0]       ex2bp_fw_data,

    input                   ls2bp_fw_act,
    input                   ls2bp_fw_vld,
    input  [4:0]            ls2bp_fw_idx,
    input  [XLEN-1:0]       ls2bp_fw_data,

    // Prediction result.
    output                  bp2if_br_tak,
    output                  bp2if_pc_vld,
    output [ALEN-1:0]       bp2if_pc_nxt
);

    localparam UDLY         = 1;
    localparam SGN_EXTW     = ALEN - 12;

    // Pipeline control.
    wire                    if2bp_real;
    reg                     if2bp_fire_p;
    reg                     if2bp_init_p;

    // For instruction decoding.
    wire [6:0]              inst_opcode;
    wire                    inst_op_bjp;
    wire                    inst_op_jal;
    wire                    inst_op_jalr;
    wire                    inst_op_branch;
    wire                    inst_op_nbjp;

    wire [11:0]             inst_i_imm;
    wire [19:0]             inst_j_imm;
    wire [11:0]             inst_b_imm;

    wire                    inst_imm_sign;
    wire [SGN_EXTW-1:0]     inst_sign_ext;
    wire [ALEN-1:0]         inst_i_imm_ext;
    wire [ALEN-1:0]         inst_j_imm_ext;
    wire [ALEN-1:0]         inst_b_imm_ext;

    // For reset status.
    reg  [2:0]              rst_r;
    reg  [ALEN-1:0]         rst_pc_r;
    wire                    rst_pc_vld;
    wire                    rst_done;

    // For reg forwarding.
    wire                    fw_if_wait;
    wire                    fw_id_wait;
    wire                    fw_frm_exu;
    wire                    fw_frm_lsu;
    wire                    fw_ex_wait;
    wire                    fw_ls_wait;
    wire                    fw_none;
    wire [XLEN-1:0]         reg_data;
    wire [ALEN-1:0]         reg_pc;

    // For prediction.
    wire                    branch_taken;
    wire                    branch_not_taken;

    // For pc add.
    wire [ALEN-1:0]         bp_add_seq;
    wire [ALEN-1:0]         bp_add_opa;
    wire [ALEN-1:0]         bp_add_opb;

    // For bp stall.
    wire                    if2bp_jalr;
    wire                    bp_force;
    wire                    bp_stall;

    reg                     op_jalr_r;
    reg  [ALEN-1:0]         imm_ext_r;

    // Pre-decode opcode.
    assign inst_opcode      = if2bp_inst[6:0];
    assign inst_op_bjp      = inst_opcode[6:4] == 3'b110;
    assign inst_op_jal      = inst_op_bjp && (inst_opcode[3:2] == 2'b11);
    assign inst_op_jalr     = inst_op_bjp && (inst_opcode[3:2] == 2'b01);
    assign inst_op_branch   = inst_op_bjp && (inst_opcode[3:2] == 2'b00);
    assign inst_op_nbjp     = ~inst_op_bjp;

    // Pre-decode immediate.
    assign inst_i_imm       = if2bp_inst[31:20];
    assign inst_b_imm       = {if2bp_inst[31], if2bp_inst[7], if2bp_inst[30:25], if2bp_inst[11:8]};
    assign inst_j_imm       = {if2bp_inst[31], if2bp_inst[19:12], if2bp_inst[20], if2bp_inst[30:21]};

    // Extend immediate to address length.
    assign inst_imm_sign    = if2bp_inst[31];
    assign inst_sign_ext    = {SGN_EXTW{inst_imm_sign}};
    assign inst_i_imm_ext   = {inst_sign_ext, inst_i_imm};
    assign inst_j_imm_ext   = {inst_sign_ext[SGN_EXTW-10:0], inst_j_imm, 1'b0};
    assign inst_b_imm_ext   = {inst_sign_ext[SGN_EXTW-2:0], inst_b_imm, 1'b0};

    // Access register file.
    assign bp2rf_rd_idx     = if2bp_inst[19:15];

    // Forward register value.
    assign fw_frm_exu       = ex2bp_fw_vld && (ex2bp_fw_idx == bp2rf_rd_idx);
    assign fw_frm_lsu       = ls2bp_fw_vld && (ls2bp_fw_idx == bp2rf_rd_idx);

    assign fw_if_wait       = if2bp_fw_act && (if2bp_fw_idx == bp2rf_rd_idx);
    assign fw_id_wait       = id2bp_fw_act && (id2bp_fw_idx == bp2rf_rd_idx);
    assign fw_ex_wait       = ex2bp_fw_act && (!ex2bp_fw_vld) && (ex2bp_fw_idx == bp2rf_rd_idx);
    assign fw_ls_wait       = ls2bp_fw_act && (!ls2bp_fw_vld) && (ls2bp_fw_idx == bp2rf_rd_idx);

    assign reg_data         = fw_frm_exu ? ex2bp_fw_data
                            : fw_frm_lsu ? ls2bp_fw_data
                            : bp2rf_rd_data;
    generate
        if (ALEN > XLEN) begin: gen_reg_pc_wider
            assign reg_pc = {{(ALEN-XLEN){1'b0}}, reg_data};
        end
        else begin: gen_reg_pc_narrower
            assign reg_pc = reg_data[XLEN-1:0];
        end
    endgenerate

    // Adopt static BTFN (Back Taken, Forward Not taken) branch prediction.
    assign branch_taken     = inst_op_branch & inst_imm_sign;
    assign branch_not_taken = inst_op_branch & (~inst_imm_sign);

    // Get adder operands.
    assign bp_add_seq       = {{(ALEN-3){1'b0}}, 3'b100};   // 'd4

    assign bp_add_opa       = rst_pc_vld ? rst_pc_r
                            : ({ALEN{inst_op_jalr}} & reg_pc)
                            | ({ALEN{inst_op_nbjp}} & if2bp_pc)
                            | ({ALEN{inst_op_jal | inst_op_branch}} & if2bp_pc);

    assign bp_add_opb       = rst_pc_vld ? {ALEN{1'b0}}
                            : ({ALEN{inst_op_jal }} & inst_j_imm_ext)
                            | ({ALEN{inst_op_jalr}} & inst_i_imm_ext)
                            | ({ALEN{branch_taken}} & inst_b_imm_ext)
                            | ({ALEN{inst_op_nbjp | branch_not_taken}} & bp_add_seq);

    //assign bp_add_opa       = rst_pc_vld ? rst_pc_r
    //                        : (inst_op_jalr | op_jalr_r) ? reg_pc
    //                        : (inst_op_jal  | inst_op_branch) ? if2bp_pc
    //                        : if2bp_pc;

    //assign bp_add_opb       = rst_pc_vld    ? {ALEN{1'b0}}
    //                        : op_jalr_r     ? imm_ext_r
    //                        : inst_op_jalr  ? inst_i_imm_ext
    //                        : inst_op_jal   ? inst_j_imm_ext
    //                        : branch_taken  ? inst_b_imm_ext
    //                        : bp_add_seq;

    // Stall prediction.
    assign if2bp_jalr       = if2bp_vld & inst_op_jalr;
    assign bp_force         = op_jalr_r & (fw_frm_exu | fw_frm_lsu)
                            & (~fw_id_wait) & (~fw_ex_wait) & (~fw_ls_wait);
                            // & (~fw_id_wait) & (~fw_ex_wait) & (~fw_ls_wait) & (~if2bp_stall);
    assign bp_stall         = (if2bp_jalr & (fw_if_wait | fw_id_wait))
                            | (op_jalr_r & (fw_id_wait | fw_ex_wait | fw_ls_wait));
                            // | (op_jalr_r & (fw_id_wait | fw_ex_wait | fw_ls_wait | if2bp_stall));

    // Get the next pc.
    //assign bp2if_pc_vld   = rst_pc_vld | if2bp_vld;
    assign bp2if_pc_vld     = rst_pc_vld | ((if2bp_vld | op_jalr_r) & (bp_force | (~bp_stall)));
    assign bp2if_pc_nxt     = bp_add_opa + bp_add_opb;

    // Resp branch taken flag.
    //assign bp2if_br_tak   = ~branch_not_taken;
    assign bp2if_br_tak     = branch_taken;

    // Buffer reset status.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rst_r <= 3'b1;
        end
        else begin
            rst_r <= #UDLY {rst_r[1:0], 1'b0};
        end
    end

    // Buffer reset PC.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rst_pc_r <= {ALEN{1'b0}};
        end
        else begin
            rst_pc_r <= #UDLY rst_pc;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            op_jalr_r <= 1'b0;
            imm_ext_r <= {ALEN{1'b0}};
        end
        else begin
            if (bp2if_pc_vld) begin
                op_jalr_r <= #UDLY 1'b0;
            end
            else if (if2bp_jalr) begin
                op_jalr_r <= #UDLY 1'b1;
                imm_ext_r <= #UDLY inst_i_imm_ext;
            end
        end
    end

    assign rst_pc_vld = ~rst_r[1] & rst_r[2];
    assign rst_done   = ~rst_r[1];

endmodule

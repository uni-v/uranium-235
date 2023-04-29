//************************************************************
// See LICENSE for license details.
//
// Module: uv_idu
//
// Designer: Owen
//
// Description:
//      Instruction Decoding Unit.
//************************************************************

`timescale 1ns / 1ps

module uv_idu
#(
    parameter ALEN = 32,
    parameter ILEN = 32,
    parameter XLEN = 32,
    parameter MLEN = XLEN / 8
)
(
    input                   clk,
    input                   rst_n,
    
    // IFU handshake.
    input                   if2id_vld,
    output                  if2id_rdy,
    
    // IFU info.
    input  [ILEN-1:0]       if2id_inst,
    input  [ALEN-1:0]       if2id_pc,
    input  [ALEN-1:0]       if2id_pc_nxt,
    input                   if2id_br_tak,

    input                   if2id_has_excp,
    input                   if2id_acc_fault,
    input                   if2id_mis_align,
    
    // EXU handshake.
    output                  id2ex_vld,
    input                   id2ex_rdy,
    
    // ALU info.
    output                  id2ex_alu_sgn,
    output                  id2ex_alu_sft,
    output                  id2ex_alu_stl,
    output                  id2ex_alu_add,
    output                  id2ex_alu_sub,
    output                  id2ex_alu_lui,
    output                  id2ex_alu_xor,
    output                  id2ex_alu_or,
    output                  id2ex_alu_and,
    output                  id2ex_alu_slt,
    output [XLEN-1:0]       id2ex_alu_opa,
    output [XLEN-1:0]       id2ex_alu_opb,
    output                  id2ex_opa_pc,
    
    // MulDiv info.
    output                  id2ex_op_mul,
    output                  id2ex_op_mix,
    output                  id2ex_op_low,
    output                  id2ex_op_div,
    output                  id2ex_op_rem,

    // CSR info.
    input                   cs2id_misa_ie,
    output                  id2ex_csr_rd,
    output                  id2ex_csr_wr,
    output                  id2ex_csr_rs,
    output                  id2ex_csr_rc,
    output                  id2ex_csr_imm,
    output [11:0]           id2ex_csr_idx,
    output [XLEN-1:0]       id2ex_csr_val,

    // LSU info.
    output                  id2ex_op_load,
    output                  id2ex_op_loadu,
    output                  id2ex_op_store,
    output [MLEN-1:0]       id2ex_ls_mask,
    output [XLEN-1:0]       id2ex_st_data,
    
    // BJP info.
    output                  id2ex_op_bjp,
    output                  id2ex_op_beq,
    output                  id2ex_op_bne,
    output                  id2ex_op_blt,
    output                  id2ex_op_bge,
    output                  id2ex_op_jal,
    output                  id2ex_op_jalr,
    output                  id2ex_op_branch,
    output [ALEN-1:0]       id2ex_bjp_base,
    output [ALEN-1:0]       id2ex_bjp_imm,
    output [ILEN-1:0]       id2ex_inst,
    output [ALEN-1:0]       id2ex_pc,
    output [ALEN-1:0]       id2ex_pc_nxt,
    output                  id2ex_br_tak,

    // Privileged info.
    output                  id2ex_op_mret,
    output                  id2ex_op_wfi,
    
    // RF read.
    output [4:0]            id2rf_ra_idx,
    output [4:0]            id2rf_rb_idx,
    input  [XLEN-1:0]       id2rf_ra_data,
    input  [XLEN-1:0]       id2rf_rb_data,
    
    // WB info.
    output                  id2ex_wb_act,
    output [4:0]            id2ex_wb_idx,

    // Excp info.
    output                  id2ex_has_excp,
    output                  id2ex_acc_fault,
    output                  id2ex_mis_align,
    output                  id2ex_ill_inst,
    output                  id2ex_env_call,
    output                  id2ex_env_break,
    
    // Forwarding info.
    output                  id2ex_rs1_vld,
    output                  id2ex_rs2_vld,
    output [4:0]            id2ex_rs1_idx,
    output [4:0]            id2ex_rs2_idx,

    output                  if2bp_fw_act,
    output [4:0]            if2bp_fw_idx,

    input                   ex2id_fw_act,
    input                   ex2id_fw_vld,
    input  [4:0]            ex2id_fw_idx,
    input  [XLEN-1:0]       ex2id_fw_data,

    input                   ex2id_br_act,
    input  [4:0]            ex2id_br_idx,

    input                   ls2id_fw_act,
    input                   ls2id_fw_vld,
    input  [4:0]            ls2id_fw_idx,
    input  [XLEN-1:0]       ls2id_fw_data,

    // Flush control from bjp misprediction.
    output                  id_br_flush,
    input                   ex_br_flush,

    // Branch info to IFU.
    output                  id2if_bjp_vld,
    output [ALEN-1:0]       id2if_bjp_addr,

    // Flush control from trap.
    input                   trap_flush,

    // Fence info.
    output                  fence_inst,
    output                  fence_data,
    output [3:0]            fence_pred,
    output [3:0]            fence_succ,
    input                   fence_done
);

    localparam UDLY         = 1;
    localparam SGN_EXTW     = XLEN - 12;
    genvar i;
    
    // Pipeline flush.
    wire                    pipe_flush;

    // Handshake.
    wire                    id_stall;
    wire                    pipe_pre;
    wire                    pipe_nxt;
    wire                    if2id_fire;
    wire                    if2id_real;
    wire                    id2ex_fire;
    wire                    id2ex_real;
    reg                     if2id_fire_p;
    reg                     if2id_init_p;
    reg                     id2ex_fire_p;
    reg                     id2ex_init_p;

    // Input buffers.
    reg  [ILEN-1:0]         if2id_inst_r;
    reg  [ALEN-1:0]         if2id_pc_r;
    reg  [ALEN-1:0]         if2id_pc_nxt_r;
    reg                     if2id_br_tak_r;

    reg                     if2id_has_excp_r;
    reg                     if2id_acc_fault_r;
    reg                     if2id_mis_align_r;

    reg                     ls2id_fw_vld_r;
    reg  [4:0]              ls2id_fw_idx_r;
    reg  [XLEN-1:0]         ls2id_fw_data_r;

    // Pipeline sources.
    wire [ILEN-1:0]         pipe_inst;
    wire [ALEN-1:0]         pipe_pc;
    wire [ALEN-1:0]         pipe_pc_nxt;
    wire                    pipe_br_tak;

    wire                    pipe_has_excp;
    wire                    pipe_acc_fault;
    wire                    pipe_mis_align;

    wire                    pipe_fw_vld;
    wire [4:0]              pipe_fw_idx;
    wire [XLEN-1:0]         pipe_fw_data;
    
    // Inst fields.
    wire                    inst_is_rvc;
    wire [15:0]             inst_rv16;
    wire [31:0]             inst_rv32;

    wire [6:0]              inst_opcode;
    wire [4:0]              inst_rd_idx;
    wire [2:0]              inst_funct3;
    wire [4:0]              inst_rs1_idx;
    wire [4:0]              inst_rs2_idx;
    wire [6:0]              inst_funct7;
    wire [11:0]             inst_i_imm;
    wire [11:0]             inst_s_imm;
    wire [11:0]             inst_b_imm;
    wire [19:0]             inst_u_imm;
    wire [19:0]             inst_j_imm;

    wire [1:0]              inst_rvc_opcode;
    wire [4:0]              inst_rvc_rs2_idx;
    wire [4:0]              inst_rvc_rs1_idx;
    wire [4:0]              inst_rvc_rd_idx;
    wire [2:0]              inst_rvc_funct3;
    wire [4:0]              inst_rvc_rs2_inc;
    wire [4:0]              inst_rvc_rs1_inc;
    wire [4:0]              inst_rvc_rd_inc;
    wire [5:0]              inst_rvc_ci_imm;
    wire [7:0]              inst_rvc_sl_imm;
    wire [7:0]              inst_rvc_ss_imm;
    wire [9:0]              inst_rvc_iw_imm;
    wire [6:0]              inst_rvc_ls_imm;
    wire [8:0]              inst_rvc_br_imm;
    wire [11:0]             inst_rvc_jp_imm;

    // Split opcode to reduce comparitors' width & num.
    // lo: opcode[1:0]; me: opcode[4:2]; hi: opcode[6:5]
    wire [1:0]              inst_opcode_lo;
    wire [2:0]              inst_opcode_me;
    wire [1:0]              inst_opcode_hi;
    wire                    inst_opcode_lo_3;
    wire                    inst_opcode_me_0;
    wire                    inst_opcode_me_1;
    wire                    inst_opcode_me_3;
    wire                    inst_opcode_me_4;
    wire                    inst_opcode_me_5;
    wire                    inst_opcode_hi_0;
    wire                    inst_opcode_hi_1;
    wire                    inst_opcode_hi_3;

    wire                    inst_rvc_opcode_0;
    wire                    inst_rvc_opcode_1;
    wire                    inst_rvc_opcode_2;
    
    // No need to split the 3-bit funct3.
    wire                    inst_funct3_0;
    wire                    inst_funct3_1;
    wire                    inst_funct3_2;
    wire                    inst_funct3_3;
    wire                    inst_funct3_4;
    wire                    inst_funct3_5;
    wire                    inst_funct3_6;
    wire                    inst_funct3_7;
    
    // Decode low 2 bits for ls mask.
    wire                    inst_funct3_lo_0;
    wire                    inst_funct3_lo_1;
    wire                    inst_funct3_lo_2;
    wire                    inst_funct3_lo_3;
    
    // Split funct7 to reduce comparitors' width & num.
    // lo: funct7[4:0]; hi: funct[6:5]
    wire [4:0]              inst_funct7_lo;
    wire [1:0]              inst_funct7_hi;
    wire                    inst_funct7_lo_0;
    wire                    inst_funct7_hi_0;
    wire                    inst_funct7_hi_1;
    wire                    inst_funct7_5_1;
    wire                    inst_funct7_0;
    wire                    inst_funct7_1;

    // RVC funct3 values.
    wire                    inst_rvc_funct3_0;
    wire                    inst_rvc_funct3_1;
    wire                    inst_rvc_funct3_2;
    wire                    inst_rvc_funct3_3;
    wire                    inst_rvc_funct3_4;
    wire                    inst_rvc_funct3_5;
    wire                    inst_rvc_funct3_6;
    wire                    inst_rvc_funct3_7;
    
    // Operations.
    wire                    inst_op_lui;
    wire                    inst_op_auipc;
    wire                    inst_op_jal;
    wire                    inst_op_jalr;
    wire                    inst_op_branch;
    wire                    inst_op_load;
    wire                    inst_op_loadu;
    wire                    inst_op_store;
    wire                    inst_op_imm;
    wire                    inst_op_arith;
    wire                    inst_op_fence;
    wire                    inst_op_fencei;
    wire                    inst_op_system;
    wire                    inst_op_envsys;
    wire                    inst_op_ecall;
    wire                    inst_op_ebreak;
    wire                    inst_op_mret;
    wire                    inst_op_wfi;
    wire                    inst_op_csr;
    wire                    inst_op_csrrw;
    wire                    inst_op_csrrs;
    wire                    inst_op_csrrc;
    wire                    inst_op_csrimm;
    wire                    inst_op_muldiv;
    wire                    inst_op_ia;
    wire                    inst_op_ls;

    wire                    inst_op_beq;
    wire                    inst_op_bne;
    wire                    inst_op_blt;
    wire                    inst_op_bge;

    wire                    inst_f3_sft;
    wire                    inst_f7_sft;
    
    // Operation aggregations.
    wire                    inst_unsgn;
    wire                    inst_sgn;
    wire                    inst_sft;
    wire                    inst_stl;
    wire                    inst_add;
    wire                    inst_sub;
    wire                    inst_lui;
    wire                    inst_xor;
    wire                    inst_or;
    wire                    inst_and;
    wire                    inst_slt;
    wire                    inst_bjp;

    wire                    inst_mul;
    wire                    inst_mix;   // For mul only.
    wire                    inst_low;   // For mul only.
    wire                    inst_div;
    wire                    inst_rem;   // For div only.

    wire                    ill_inst;
    
    // Mask for both 32b & 64b
    wire [7:0]              ls_mask;
    
    // Operands
    wire                    inst_opa_pc;
    wire [XLEN-1:0]         inst_opa;
    wire [XLEN-1:0]         inst_opb;
    
    wire [SGN_EXTW-1:0]     inst_sign_ext;
    wire [XLEN-1:0]         inst_i_imm_ext;
    wire [XLEN-1:0]         inst_s_imm_ext;
    wire [XLEN-1:0]         inst_b_imm_ext;
    wire [XLEN-1:0]         inst_u_imm_ext;
    wire [XLEN-1:0]         inst_j_imm_ext;

    wire                    inst_opb_frm_r;
    wire                    inst_opb_imm_i;
    wire                    inst_opb_imm_s;
    wire                    inst_opb_imm_b;
    wire                    inst_opb_imm_u;
    wire                    inst_opb_imm_j;
    wire                    inst_opb_seq_j;

    wire                    inst_rs1_zero;
    wire                    inst_rs2_zero;

    wire [11:0]             inst_csr_idx;
    wire [XLEN-1:0]         inst_csr_val;

    // PC addend
    wire [ALEN-1:0]         inst_bjp_base;
    wire [ALEN-1:0]         inst_bjp_imm;
    wire [XLEN-1:0]         inst_pc_seq;
    
    // WB state
    wire                    inst_rd_idx_z;
    wire                    inst_wb_act;
    
    // Forwarding state
    wire                    rs1_vld;
    wire                    rs2_vld;
    wire                    rs2_imm;
    wire                    rs1_frm_ex;
    wire                    rs2_frm_ex;
    wire                    rs1_frm_ls;
    wire                    rs2_frm_ls;
    wire [XLEN-1:0]         rs1_data;
    wire [XLEN-1:0]         rs2_data;
    
    // Branch sources.
    wire [ALEN-1:0]         bjp_base;
    wire [ALEN-1:0]         bjp_offset;

    // Branch results.
    wire                    rs1_id_wait;
    wire                    rs2_id_wait;
    wire                    rs1_br_wait;
    wire                    rs2_br_wait;
    wire                    rs1_ex_wait;
    wire                    rs2_ex_wait;
    wire                    rs1_ls_wait;
    wire                    rs2_ls_wait;
    wire                    rs1_wait;
    wire                    rs2_wait;
    wire                    rs_wait;
    wire [XLEN-1:0]         rs_xor;

    wire                    cmp_eq;
    wire                    cmp_ne;
    wire                    cmp_lt;
    wire                    cmp_ge;

    wire                    bjp_eq;
    wire                    bjp_ne;
    wire                    bjp_lt;
    wire                    bjp_ge;

    wire                    bjp_tak;
    wire                    bjp_mis;

    wire                    bjp_vld;
    wire [ALEN-1:0]         bjp_addr;

    // Pipeline stalling states
    wire                    pipe_stall;
    reg                     pipe_stall_p;
    
    // Handshake registers
    reg                     id2ex_vld_r;
    
    // ALU registers
    reg                     alu_sgn_r;
    reg                     alu_sft_r;
    reg                     alu_stl_r;
    reg                     alu_add_r;
    reg                     alu_sub_r;
    reg                     alu_lui_r;
    reg                     alu_xor_r;
    reg                     alu_or_r;
    reg                     alu_and_r;
    reg                     alu_slt_r;
    reg  [XLEN-1:0]         alu_opa_r;
    reg  [XLEN-1:0]         alu_opb_r;
    reg                     opa_pc_r;

    // CSR registers
    reg                     csr_rd_r;
    reg                     csr_wr_r;
    reg                     csr_rs_r;
    reg                     csr_rc_r;
    reg                     csr_imm_r;
    reg  [11:0]             csr_idx_r;
    reg  [XLEN-1:0]         csr_val_r;
    
    // MulDiv registers
    reg                     op_mul_r;
    reg                     op_mix_r;
    reg                     op_low_r;
    reg                     op_div_r;
    reg                     op_rem_r;

    // LSU registers
    reg                     op_load_r;
    reg                     op_loadu_r;
    reg                     op_store_r;
    reg  [MLEN-1:0]         ls_mask_r;
    reg  [XLEN-1:0]         st_data_r;
    
    // BJP registers
    reg                     op_bjp_r;
    reg                     op_beq_r;
    reg                     op_bne_r;
    reg                     op_blt_r;
    reg                     op_bge_r;
    reg                     op_jal_r;
    reg                     op_jalr_r;
    reg                     op_branch_r;
    
    reg  [ALEN-1:0]         bjp_base_r;
    reg  [ALEN-1:0]         bjp_imm_r;
    reg  [ILEN-1:0]         inst_r;
    reg  [ALEN-1:0]         pc_r;
    reg  [ALEN-1:0]         pc_nxt_r;
    reg                     br_tak_r;

    // Privileged inst buf.
    reg                     op_mret_r;
    reg                     op_wfi_r;
    
    // WB registers
    reg                     wb_act_r;
    reg  [4:0]              wb_idx_r;
    
    // Forwarding registers
    reg                     rs1_vld_r;
    reg                     rs2_vld_r;
    reg  [4:0]              rs1_idx_r;
    reg  [4:0]              rs2_idx_r;
    
    // Pipeline flush
    reg                     bjp_mis_r;
    reg                     bjp_vld_r;
    reg  [ALEN-1:0]         bjp_addr_r;

    // Pipeline stalling register
    reg                     pipe_stall_r;

    // Fence registers
    reg                     fencei_r;
    reg                     fence_r;
    reg  [3:0]              fence_pred_r;
    reg  [3:0]              fence_succ_r;

    // Exceptions.
    reg                     has_excp_r;
    reg                     acc_fault_r;
    reg                     mis_align_r;
    reg                     ill_inst_r;
    reg                     env_call_r;
    reg                     env_break_r;
    
    // Two flush sources: bjp & trap.
    assign pipe_flush       = id_br_flush | ex_br_flush | trap_flush;

    // Pipeline control.
    assign id_stall         = 1'b0;
    assign pipe_stall       = id_stall;
    //assign pipe_stall       = id_stall | rs1_ls_wait | rs1_ls_wait;

    // Handshake: rsp to IFU.
    assign pipe_pre         = if2id_vld & (~pipe_flush);
    assign pipe_nxt         = pipe_pre  & (~pipe_stall);
    assign if2id_rdy        = id2ex_rdy & (~pipe_stall);
    assign if2id_fire       = if2id_vld & if2id_rdy;
    assign if2id_real       = if2id_fire_p | if2id_init_p;
    assign id2ex_fire       = id2ex_vld & id2ex_rdy;
    assign id2ex_real       = id2ex_fire_p | id2ex_init_p;
    
    // Handshake: req to EXU.
    assign id2ex_vld        = id2ex_vld_r & (~pipe_flush) & (~pipe_stall_p);

    // Select pipeline sources.
    assign pipe_inst        = if2id_real ? if2id_inst       : if2id_inst_r;
    assign pipe_pc          = if2id_real ? if2id_pc         : if2id_pc_r;
    assign pipe_pc_nxt      = if2id_real ? if2id_pc_nxt     : if2id_pc_nxt_r;
    assign pipe_br_tak      = if2id_real ? if2id_br_tak     : if2id_br_tak_r;

    assign pipe_has_excp    = if2id_real ? if2id_has_excp   : if2id_has_excp_r;
    assign pipe_acc_fault   = if2id_real ? if2id_acc_fault  : if2id_acc_fault_r;
    assign pipe_mis_align   = if2id_real ? if2id_mis_align  : if2id_mis_align_r;

    //assign pipe_fw_vld      = id2ex_real ? ls2id_fw_vld     : ls2id_fw_vld_r;
    //assign pipe_fw_idx      = id2ex_real ? ls2id_fw_idx     : ls2id_fw_idx_r;
    //assign pipe_fw_data     = id2ex_real ? ls2id_fw_data    : ls2id_fw_data_r;

    assign pipe_fw_vld      = ls2id_fw_vld ;
    assign pipe_fw_idx      = ls2id_fw_idx ;
    assign pipe_fw_data     = ls2id_fw_data;
    
    // Decode instruction fields.
    assign inst_is_rvc      = ~(pipe_inst[0] & pipe_inst[1]);
    assign inst_rv16        = pipe_inst[15:0];
    assign inst_rv32        = pipe_inst[31:0];

    assign inst_opcode      = inst_rv32[6:0];
    assign inst_rd_idx      = inst_rv32[11:7];
    assign inst_funct3      = inst_rv32[14:12];
    assign inst_rs1_idx     = inst_rv32[19:15];
    assign inst_rs2_idx     = inst_rv32[24:20];
    assign inst_funct7      = inst_rv32[31:25];
    assign inst_i_imm       = inst_rv32[31:20];
    assign inst_s_imm       = {inst_rv32[31:25], inst_rv32[11:7]};
    assign inst_b_imm       = {inst_rv32[31], inst_rv32[7], inst_rv32[30:25], inst_rv32[11:8]};
    assign inst_u_imm       = inst_rv32[31:12];
    assign inst_j_imm       = {inst_rv32[31], inst_rv32[19:12], inst_rv32[20], inst_rv32[30:21]};

    // Split & compare opcode.
    assign inst_opcode_lo   = inst_opcode[1:0];
    assign inst_opcode_me   = inst_opcode[4:2];
    assign inst_opcode_hi   = inst_opcode[6:5];
    assign inst_opcode_lo_3 = inst_opcode_lo == 2'h3;
    assign inst_opcode_me_0 = inst_opcode_me == 3'h0;
    assign inst_opcode_me_1 = inst_opcode_me == 3'h1;
    assign inst_opcode_me_3 = inst_opcode_me == 3'h3;
    assign inst_opcode_me_4 = inst_opcode_me == 3'h4;
    assign inst_opcode_me_5 = inst_opcode_me == 3'h5;
    assign inst_opcode_hi_0 = inst_opcode_hi == 2'h0;
    assign inst_opcode_hi_1 = inst_opcode_hi == 2'h1;
    assign inst_opcode_hi_3 = inst_opcode_hi == 2'h3;
    
    // Compare funct3.
    assign inst_funct3_0    = inst_funct3 == 3'h0;
    assign inst_funct3_1    = inst_funct3 == 3'h1;
    assign inst_funct3_2    = inst_funct3 == 3'h2;
    assign inst_funct3_3    = inst_funct3 == 3'h3;
    assign inst_funct3_4    = inst_funct3 == 3'h4;
    assign inst_funct3_5    = inst_funct3 == 3'h5;
    assign inst_funct3_6    = inst_funct3 == 3'h6;
    assign inst_funct3_7    = inst_funct3 == 3'h7;
    
    assign inst_funct3_lo_0 = inst_funct3[1:0] == 2'h0;
    assign inst_funct3_lo_1 = inst_funct3[1:0] == 2'h1;
    assign inst_funct3_lo_2 = inst_funct3[1:0] == 2'h2;
    assign inst_funct3_lo_3 = inst_funct3[1:0] == 2'h3;
    
    // Split & compare funct7.
    assign inst_funct7_lo   = inst_funct7[4:0];
    assign inst_funct7_hi   = inst_funct7[6:5];
    assign inst_funct7_lo_0 = inst_funct7_lo == 5'h0;
    assign inst_funct7_lo_8 = inst_funct7_lo == 5'h8;
    assign inst_funct7_hi_0 = inst_funct7_hi == 2'h0;
    assign inst_funct7_hi_1 = inst_funct7_hi == 2'h1;
    assign inst_funct7_5_1  = inst_funct7[5];
    assign inst_funct7_0    = inst_funct7 == 7'h0;
    assign inst_funct7_1    = inst_funct7 == 7'h1;

    // Decode RVC fields.
    assign inst_rvc_opcode  = inst_rv16[1:0];
    assign inst_rvc_rs2_idx = inst_rv16[6:2];
    assign inst_rvc_rs1_idx = inst_rv16[11:7];
    assign inst_rvc_rd_idx  = inst_rv16[11:7];
    assign inst_rvc_funct3  = inst_rv16[15:13];

    assign inst_rvc_rs2_inc = {2'b0, inst_rv16[4:2]} + 5'd8;
    assign inst_rvc_rs1_inc = {2'b0, inst_rv16[9:7]} + 5'd8;
    assign inst_rvc_rd_inc  = {2'b0, inst_rv16[4:2]} + 5'd8;

    assign inst_rvc_ci_imm  = {inst_rv16[12], inst_rv16[6:2]};
    assign inst_rvc_sl_imm  = {inst_rv16[3:2], inst_rv16[12], inst_rv16[6:4], 2'b0};
    assign inst_rvc_ss_imm  = {inst_rv16[8:7], inst_rv16[12:9], 2'b0};
    assign inst_rvc_iw_imm  = {inst_rv16[10:7], inst_rv16[12:11], inst_rv16[5], inst_rv16[6], 2'b0};
    assign inst_rvc_ls_imm  = {inst_rv16[5], inst_rv16[12:10], inst_rv16[6], 2'b0};
    assign inst_rvc_br_imm  = {inst_rv16[12], inst_rv16[6:5], inst_rv16[2], inst_rv16[11:10], inst_rv16[4:3], 1'b0};
    assign inst_rvc_jp_imm  = {inst_rv16[12], inst_rv16[8], inst_rv16[10:9], inst_rv16[6], inst_rv16[7], inst_rv16[6:5], inst_rv16[2], inst_rv16[11], inst_rv16[5:3], 1'b0};
    
    assign inst_rvc_opcode_0 = inst_rvc_opcode == 2'h0;
    assign inst_rvc_opcode_1 = inst_rvc_opcode == 2'h1;
    assign inst_rvc_opcode_2 = inst_rvc_opcode == 2'h2;

    assign inst_rvc_funct3_0 = inst_rvc_funct3 == 3'h0;
    assign inst_rvc_funct3_1 = inst_rvc_funct3 == 3'h1;
    assign inst_rvc_funct3_2 = inst_rvc_funct3 == 3'h2;
    assign inst_rvc_funct3_3 = inst_rvc_funct3 == 3'h3;
    assign inst_rvc_funct3_4 = inst_rvc_funct3 == 3'h4;
    assign inst_rvc_funct3_5 = inst_rvc_funct3 == 3'h5;
    assign inst_rvc_funct3_6 = inst_rvc_funct3 == 3'h6;
    assign inst_rvc_funct3_7 = inst_rvc_funct3 == 3'h7;
    
    // Decode instruction operations.
    assign inst_op_lui      = inst_opcode_lo_3 & inst_opcode_me_5 & inst_opcode_hi_1;
    assign inst_op_auipc    = inst_opcode_lo_3 & inst_opcode_me_5 & inst_opcode_hi_0;
    assign inst_op_jal      = inst_opcode_lo_3 & inst_opcode_me_3 & inst_opcode_hi_3;
    assign inst_op_jalr     = inst_opcode_lo_3 & inst_opcode_me_1 & inst_opcode_hi_3;
    assign inst_op_branch   = inst_opcode_lo_3 & inst_opcode_me_0 & inst_opcode_hi_3;
    assign inst_op_load     = inst_opcode_lo_3 & inst_opcode_me_0 & inst_opcode_hi_0;
    assign inst_op_loadu    = inst_op_load & inst_funct3[2];
    assign inst_op_store    = inst_opcode_lo_3 & inst_opcode_me_0 & inst_opcode_hi_1;
    assign inst_op_imm      = inst_opcode_lo_3 & inst_opcode_me_4 & inst_opcode_hi_0;
    assign inst_op_arith    = inst_opcode_lo_3 & inst_opcode_me_4 & inst_opcode_hi_1;
    assign inst_op_fence    = inst_opcode_lo_3 & inst_opcode_me_3 & inst_opcode_hi_0 & inst_funct3_0;
    assign inst_op_fencei   = inst_opcode_lo_3 & inst_opcode_me_3 & inst_opcode_hi_0 & inst_funct3_1;
    assign inst_op_system   = inst_opcode_lo_3 & inst_opcode_me_4 & inst_opcode_hi_3;
    assign inst_op_envsys   = inst_op_system & inst_funct3_0 & inst_funct7_0;
    assign inst_op_ecall    = inst_op_envsys & (~inst_i_imm[0]);
    assign inst_op_ebreak   = inst_op_envsys & inst_i_imm[0];
    assign inst_op_mret     = inst_op_system && inst_funct3_0 && (inst_funct7 == 7'b11000)
                            && (inst_rd_idx == 5'b0) && (inst_rs1_idx == 5'b0) && (inst_rs2_idx == 5'b10);
    assign inst_op_wfi      = inst_op_system && inst_funct3_0 && (inst_funct7 == 7'b1000)
                            && (inst_rd_idx == 5'b0) && (inst_rs1_idx == 5'b0) && (inst_rs2_idx == 5'b101);
    assign inst_op_csr      = inst_op_system & (|inst_funct3[1:0]);
    assign inst_op_csrrw    = inst_op_csr && (inst_funct3[1:0] == 2'b01);
    assign inst_op_csrrs    = inst_op_csr && (inst_funct3[1:0] == 2'b10);
    assign inst_op_csrrc    = inst_op_csr && (inst_funct3[1:0] == 2'b11);
    assign inst_op_csrimm   = inst_op_csr & inst_funct3[2];
    assign inst_op_muldiv   = inst_op_arith & inst_funct7_1;
    
    assign inst_op_ls       = inst_op_load  | inst_op_store;
    assign inst_op_ia       = inst_op_imm   | inst_op_arith;
    assign inst_f3_sft      = inst_funct3_1 | inst_funct3_5;
    assign inst_f7_sft      = inst_funct7_0 | inst_funct7_5_1;

    assign inst_op_beq      = inst_op_branch & inst_funct3_0;
    assign inst_op_bne      = inst_op_branch & inst_funct3_1;
    assign inst_op_bge      = inst_op_branch & (inst_funct3_4 | inst_funct3_6);
    assign inst_op_blt      = inst_op_branch & (inst_funct3_5 | inst_funct3_7);
    
    assign ls_mask          = {8{inst_funct3_lo_0}} & 8'h01 
                            | {8{inst_funct3_lo_1}} & 8'h03
                            | {8{inst_funct3_lo_2}} & 8'h0f
                            | {8{inst_funct3_lo_3}} & 8'hff;
    
    assign inst_unsgn       = (inst_sft & (~inst_funct7_5_1))
                            | (inst_add & inst_op_branch & inst_funct3[1])
                            | (inst_add & inst_slt & inst_funct3[0])
                            | (inst_mul & inst_funct3[1])
                            | (inst_div & inst_funct3[0]);
    assign inst_sgn         = ~inst_unsgn;
    assign inst_sft         = inst_op_ia & inst_f3_sft & inst_f7_sft;
    assign inst_stl         = inst_op_ia & inst_funct3_1;
    assign inst_add         = inst_bjp | inst_slt | inst_op_ls | inst_op_auipc
                            | (inst_op_ia & inst_funct3_0);
    assign inst_sub         = (inst_op_arith & inst_funct3_0 & inst_funct7_5_1)
                            | inst_op_branch | inst_slt;
    assign inst_lui         = inst_op_lui;
    assign inst_xor         = inst_op_ia & inst_funct3_4;
    assign inst_or          = inst_op_ia & inst_funct3_6;
    assign inst_and         = inst_op_ia & inst_funct3_7;
    assign inst_slt         = inst_op_ia & (inst_funct3_2 | inst_funct3_3);
    assign inst_bjp         = inst_op_branch | inst_op_jal | inst_op_jalr;

    assign inst_mul         = inst_op_muldiv & (~inst_funct3[2]);
    assign inst_mix         = inst_op_muldiv & inst_funct3[1] & (~inst_funct3[0]);
    assign inst_low         = inst_op_muldiv & inst_funct3_0;
    assign inst_div         = inst_op_muldiv & inst_funct3[2];
    assign inst_rem         = inst_op_muldiv & inst_funct3[1];

    // Detect illegal instruction.
    assign ill_inst         = if2id_vld & ((~(|pipe_inst)) | (&pipe_inst)
                            | (~(inst_op_lui | inst_op_auipc | inst_op_ls | inst_op_ia
                            | inst_op_system | inst_op_fence | inst_op_fencei | inst_bjp)));
    
    // Extend immediate number.
    assign inst_sign_ext    = {SGN_EXTW{inst_rv32[31]}};
    assign inst_i_imm_ext   = {inst_sign_ext, inst_i_imm};
    assign inst_s_imm_ext   = {inst_sign_ext, inst_s_imm};
    assign inst_b_imm_ext   = {inst_sign_ext[SGN_EXTW-2:0], inst_b_imm, 1'b0};
    assign inst_u_imm_ext   = {inst_u_imm, 12'b0};
    assign inst_j_imm_ext   = {inst_sign_ext[SGN_EXTW-10:0], inst_j_imm, 1'b0};
    
    // Set operands.
    assign inst_opb_frm_r   = inst_op_branch | inst_op_arith;
    assign inst_opb_imm_i   = inst_op_load | inst_op_imm;
    assign inst_opb_imm_s   = inst_op_store;
    assign inst_opb_imm_b   = 1'b0;
    assign inst_opb_imm_u   = inst_op_lui | inst_op_auipc;
    assign inst_opb_imm_j   = inst_op_jal;
    assign inst_opb_seq_j   = inst_op_jal | inst_op_jalr;
    assign inst_pc_seq      = {{(XLEN-3){1'b0}}, 3'd4};

    assign inst_bjp_base    = inst_op_jalr ? rs1_data[ALEN-1:0] : pipe_pc;
    assign inst_bjp_imm     = inst_op_branch ? inst_b_imm_ext[ALEN-1:0]
                            : inst_op_jalr   ? inst_i_imm_ext[ALEN-1:0]
                            : inst_j_imm_ext[ALEN-1:0];
    assign inst_opa_pc      = inst_op_auipc | inst_op_jal | inst_op_jalr;

    assign inst_opa         = inst_opa_pc ? pipe_pc : rs1_data;
    assign inst_opb         = ({XLEN{inst_opb_frm_r}} & rs2_data      )
                            | ({XLEN{inst_opb_imm_i}} & inst_i_imm_ext)
                            | ({XLEN{inst_opb_imm_s}} & inst_s_imm_ext)
                            | ({XLEN{inst_opb_imm_b}} & inst_b_imm_ext)
                            | ({XLEN{inst_opb_imm_u}} & inst_u_imm_ext)
                            | ({XLEN{inst_opb_seq_j}} & inst_pc_seq   );
    
    assign inst_rd_zero     = inst_rd_idx  == 5'd0;
    assign inst_rs1_zero    = inst_rs1_idx == 5'd0;
    assign inst_rs2_zero    = inst_rs2_idx == 5'd0;

    assign inst_csr_idx     = inst_i_imm;
    assign inst_csr_val     = inst_op_csrimm ? {{(XLEN-5){1'b0}}, inst_rs1_idx} : rs1_data;

    // Select wb-active inst.
    assign inst_rd_idx_z    = inst_rd_idx == 5'h0;
    assign inst_wb_act      = ~(inst_rd_idx_z | inst_op_branch | inst_op_store);
    
    // Set if the operand is valid.
    assign rs1_vld          = ~(inst_op_lui   | inst_op_auipc  | inst_op_jal | inst_op_csrimm
                              | inst_op_fence | inst_op_fencei | inst_op_envsys);
    assign rs2_vld          = ~(inst_op_load | inst_op_imm | inst_op_jalr | inst_op_csr) & rs1_vld;
    assign rs2_imm          = inst_op_load | inst_op_imm | inst_op_jalr;

    // Set if the reg values are from the bypass network.
    assign rs1_frm_ex       = ex2id_fw_vld && (ex2id_fw_idx == inst_rs1_idx);
    assign rs2_frm_ex       = ex2id_fw_vld && (ex2id_fw_idx == inst_rs2_idx);
    assign rs1_frm_ls       = ls2id_fw_vld && (ls2id_fw_idx == inst_rs1_idx);
    assign rs2_frm_ls       = ls2id_fw_vld && (ls2id_fw_idx == inst_rs2_idx);
    assign rs1_ex_wait      = ex2id_fw_act && (!ex2id_fw_vld) && (ex2id_fw_idx == inst_rs1_idx);
    assign rs2_ex_wait      = ex2id_fw_act && (!ex2id_fw_vld) && (ex2id_fw_idx == inst_rs2_idx);
    assign rs1_ls_wait      = ls2id_fw_act && (!ls2id_fw_vld) && (ls2id_fw_idx == inst_rs1_idx);
    assign rs2_ls_wait      = ls2id_fw_act && (!ls2id_fw_vld) && (ls2id_fw_idx == inst_rs2_idx);
    assign rs1_data         = rs1_frm_ex ? ex2id_fw_data
                            : rs1_frm_ls ? ls2id_fw_data
                            : id2rf_ra_data;
    assign rs2_data         = rs2_frm_ex ? ex2id_fw_data
                            : rs2_frm_ls ? ls2id_fw_data
                            : id2rf_rb_data;

`ifdef BR_FLUSH_AT_DEC
    // Set branch sources.
    assign bjp_base         = pipe_pc;
    assign bjp_offset       = inst_b_imm_ext[ALEN-1:0];

    // Summary branch states.
    assign rs1_id_wait      = id2ex_wb_act && (id2ex_wb_idx == inst_rs1_idx);
    assign rs2_id_wait      = id2ex_wb_act && (id2ex_wb_idx == inst_rs2_idx);
    assign rs1_br_wait      = ex2id_br_act && (!ex2id_fw_vld) && (ex2id_br_idx == inst_rs1_idx);
    assign rs2_br_wait      = ex2id_br_act && (!ex2id_fw_vld) && (ex2id_br_idx == inst_rs2_idx);
    assign rs1_wait         = rs1_id_wait | rs1_br_wait | rs1_ls_wait;
    assign rs2_wait         = rs2_id_wait | rs2_br_wait | rs2_ls_wait;
    assign rs_wait          = rs1_wait | rs2_wait;
    assign rs_xor           = rs1_data ^ rs2_data;

    assign cmp_eq           = ~cmp_ne;
    assign cmp_ne           = |rs_xor;
    assign cmp_lt           = (inst_rs1_zero & (~rs2_data[XLEN-1]) & (|rs2_data[XLEN-2:0]))
                            | (inst_rs2_zero &   rs1_data[XLEN-1]);
    assign cmp_ge           = (inst_rs1_zero & ( rs2_data[XLEN-1] | (~(|rs2_data))))
                            | (inst_rs2_zero & (~rs1_data[XLEN-1]));

    assign bjp_eq           = inst_op_beq & cmp_eq;
    assign bjp_ne           = inst_op_bne & cmp_ne;
    assign bjp_lt           = inst_op_blt & (~inst_funct3[1]) & cmp_lt; // Must be signed cmp.
    assign bjp_ge           = inst_op_bge & (~inst_funct3[1]) & cmp_ge; // Must be signed cmp.

    assign bjp_tak          = (~rs_wait) & (bjp_eq | bjp_ne | bjp_lt | bjp_ge);
    assign bjp_mis          = if2id_fire && ((bjp_tak && (!pipe_br_tak))
                                         && (bjp_addr != pipe_pc_nxt));
    
    assign bjp_vld          = bjp_mis;
    assign bjp_addr         = bjp_base + bjp_offset;
`else
    assign bjp_mis          = 1'b0;
    assign bjp_vld          = 1'b0;
    assign bjp_addr         = {ALEN{1'b0}};
`endif
    
    // Buffer handshake firing.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            if2id_fire_p <= 1'b0;
        end
        else begin
            if2id_fire_p <= #UDLY if2id_fire;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            if2id_init_p <= 1'b1;
        end
        else begin
            if2id_init_p <= #UDLY ~if2id_vld;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            id2ex_fire_p <= 1'b0;
        end
        else begin
            id2ex_fire_p <= #UDLY id2ex_fire;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            id2ex_init_p <= 1'b1;
        end
        else begin
            id2ex_init_p <= #UDLY ~id2ex_vld;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            id2ex_vld_r <= 1'b0;
        end
        else begin
            if (pipe_pre) begin
                id2ex_vld_r <= #UDLY 1'b1;
            end
            else if (id2ex_rdy | pipe_flush) begin
                id2ex_vld_r <= #UDLY 1'b0;
            end
        end
    end

    // Buffer stall status.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            pipe_stall_p <= 1'b0;
        end
        else begin
            if (pipe_flush) begin
                pipe_stall_p <= #UDLY 1'b0;
            end
            else begin
                pipe_stall_p <= #UDLY pipe_stall;
            end
        end
    end

    // Buffer input.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            if2id_inst_r      <= {ILEN{1'b0}};
            if2id_pc_r        <= {ALEN{1'b0}};
            if2id_pc_nxt_r    <= {ALEN{1'b0}};
            if2id_br_tak_r    <= 1'b0;
            if2id_has_excp_r  <= 1'b0;
            if2id_acc_fault_r <= 1'b0;
            if2id_mis_align_r <= 1'b0;
        end
        else begin
            if (if2id_real) begin
                if2id_inst_r      <= #UDLY if2id_inst;
                if2id_pc_r        <= #UDLY if2id_pc;
                if2id_pc_nxt_r    <= #UDLY if2id_pc_nxt;
                if2id_br_tak_r    <= #UDLY if2id_br_tak;
                if2id_has_excp_r  <= #UDLY if2id_has_excp;
                if2id_acc_fault_r <= #UDLY if2id_acc_fault;
                if2id_mis_align_r <= #UDLY if2id_mis_align;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            ls2id_fw_vld_r    <= 1'b0;
            ls2id_fw_idx_r    <= 5'b0;
            ls2id_fw_data_r   <= {XLEN{1'b0}};
        end
        else begin
            if (id2ex_real) begin
                ls2id_fw_vld_r    <= #UDLY ls2id_fw_vld;
                ls2id_fw_idx_r    <= #UDLY ls2id_fw_idx;
                ls2id_fw_data_r   <= #UDLY ls2id_fw_data;
            end
        end
    end

    // Buffer ALU info.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            alu_sgn_r <= 1'b0;
            alu_sft_r <= 1'b0;
            alu_stl_r <= 1'b0;
            alu_add_r <= 1'b0;
            alu_sub_r <= 1'b0;
            alu_lui_r <= 1'b0;
            alu_xor_r <= 1'b0;
            alu_or_r  <= 1'b0;
            alu_and_r <= 1'b0;
            alu_slt_r <= 1'b0;
            alu_opa_r <= {XLEN{1'b0}};
            alu_opb_r <= {XLEN{1'b0}};
            opa_pc_r  <= 1'b0;
        end
        else begin
            if (pipe_nxt) begin
                alu_sgn_r <= #UDLY inst_sgn;
                alu_sft_r <= #UDLY inst_sft;
                alu_stl_r <= #UDLY inst_stl;
                alu_add_r <= #UDLY inst_add;
                alu_sub_r <= #UDLY inst_sub;
                alu_lui_r <= #UDLY inst_lui;
                alu_xor_r <= #UDLY inst_xor;
                alu_or_r  <= #UDLY inst_or;
                alu_and_r <= #UDLY inst_and;
                alu_slt_r <= #UDLY inst_slt;
                alu_opa_r <= #UDLY inst_opa;
                alu_opb_r <= #UDLY inst_opb;
                opa_pc_r  <= #UDLY inst_opa_pc;
            end
        end
    end
    
    assign id2ex_alu_sgn  = alu_sgn_r;
    assign id2ex_alu_sft  = alu_sft_r;
    assign id2ex_alu_stl  = alu_stl_r;
    assign id2ex_alu_add  = alu_add_r;
    assign id2ex_alu_sub  = alu_sub_r;
    assign id2ex_alu_lui  = alu_lui_r;
    assign id2ex_alu_xor  = alu_xor_r;
    assign id2ex_alu_or   = alu_or_r;
    assign id2ex_alu_and  = alu_and_r;
    assign id2ex_alu_slt  = alu_slt_r;
    assign id2ex_alu_opa  = alu_opa_r;
    assign id2ex_alu_opb  = alu_opb_r;
    assign id2ex_opa_pc   = opa_pc_r;

    // Buffer MulDiv info.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            op_mul_r <= 1'b0;
            op_mix_r <= 1'b0;
            op_low_r <= 1'b0;
            op_div_r <= 1'b0;
            op_rem_r <= 1'b0;
        end
        else begin
            if (pipe_nxt) begin
                op_mul_r <= #UDLY inst_mul;
                op_mix_r <= #UDLY inst_mix;
                op_low_r <= #UDLY inst_low;
                op_div_r <= #UDLY inst_div;
                op_rem_r <= #UDLY inst_rem;
            end
        end
    end

    assign id2ex_op_mul = op_mul_r;
    assign id2ex_op_mix = op_mix_r;
    assign id2ex_op_low = op_low_r;
    assign id2ex_op_div = op_div_r;
    assign id2ex_op_rem = op_rem_r;

    // Buffer CSR info.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            csr_rd_r   <= 1'b0;
            csr_wr_r   <= 1'b0;
            csr_rs_r   <= 1'b0;
            csr_rc_r   <= 1'b0;
            csr_imm_r  <= 1'b0;
            csr_idx_r  <= 12'b0;
            csr_val_r  <= {XLEN{1'b0}};
        end
        else begin
            if (pipe_nxt) begin
                csr_rd_r   <= #UDLY inst_op_csr & (~(inst_op_csrrw & inst_rd_zero));
                csr_wr_r   <= #UDLY inst_op_csr & (~(inst_op_csrrs & inst_rs1_zero));
                csr_rs_r   <= #UDLY inst_op_csrrs;
                csr_rc_r   <= #UDLY inst_op_csrrc;
                csr_imm_r  <= #UDLY inst_op_csrimm;
                csr_idx_r  <= #UDLY inst_csr_idx;
                csr_val_r  <= #UDLY inst_csr_val;
            end
        end
    end

    assign id2ex_csr_rd   = csr_rd_r;
    assign id2ex_csr_wr   = csr_wr_r;
    assign id2ex_csr_rs   = csr_rs_r;
    assign id2ex_csr_rc   = csr_rc_r;
    assign id2ex_csr_imm  = csr_imm_r;
    assign id2ex_csr_idx  = csr_idx_r;
    assign id2ex_csr_val  = csr_val_r;
    
    // Buffer LSU info.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            op_load_r  <= 1'b0;
            op_loadu_r <= 1'b0;
            op_store_r <= 1'b0;
            ls_mask_r  <= {MLEN{1'b0}};
            st_data_r  <= {XLEN{1'b0}};
        end
        else begin
            if (pipe_nxt) begin
                op_load_r  <= #UDLY inst_op_load;
                op_loadu_r <= #UDLY inst_op_loadu;
                op_store_r <= #UDLY inst_op_store;
                ls_mask_r  <= #UDLY {MLEN{inst_op_ls}} & ls_mask[MLEN-1:0];
                if (inst_op_store) begin
                    //st_data_r  <= #UDLY id2rf_rb_data;
                    st_data_r  <= #UDLY rs2_data;
                end
            end
        end
    end
    
    assign id2ex_op_load  = op_load_r;
    assign id2ex_op_loadu = op_loadu_r;
    assign id2ex_op_store = op_store_r;
    assign id2ex_ls_mask  = ls_mask_r;
    assign id2ex_st_data  = st_data_r;
    
    // Buffer JMP info.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            op_bjp_r    <= 1'b0;
            op_beq_r    <= 1'b0;
            op_bne_r    <= 1'b0;
            op_blt_r    <= 1'b0;
            op_bge_r    <= 1'b0;
            op_jal_r    <= 1'b0;
            op_jalr_r   <= 1'b0;
            op_branch_r <= 1'b0;
            bjp_base_r  <= {ALEN{1'b0}};
            bjp_imm_r   <= {ALEN{1'b0}};
            inst_r      <= {ILEN{1'b0}};
            pc_r        <= {ALEN{1'b0}};
            pc_nxt_r    <= {ALEN{1'b0}};
            br_tak_r    <= 1'b0;
        end
        else begin
            if (pipe_nxt) begin
                op_bjp_r    <= #UDLY inst_op_branch | inst_op_jal | inst_op_jalr;
                op_beq_r    <= #UDLY inst_op_beq;
                op_bne_r    <= #UDLY inst_op_bne;
                op_blt_r    <= #UDLY inst_op_bge;
                op_bge_r    <= #UDLY inst_op_blt;
                op_jal_r    <= #UDLY inst_op_jal;
                op_jalr_r   <= #UDLY inst_op_jalr;
                op_branch_r <= #UDLY inst_op_branch;
                bjp_base_r  <= #UDLY inst_bjp_base;
                bjp_imm_r   <= #UDLY inst_bjp_imm;
                inst_r      <= #UDLY pipe_inst;
                pc_r        <= #UDLY pipe_pc;
                pc_nxt_r    <= #UDLY pipe_pc_nxt;
                br_tak_r    <= #UDLY pipe_br_tak;
            end
        end
    end
    
    assign id2ex_op_bjp     = op_bjp_r;
    assign id2ex_op_beq     = op_beq_r;
    assign id2ex_op_bne     = op_bne_r;
    assign id2ex_op_blt     = op_blt_r;
    assign id2ex_op_bge     = op_bge_r;
    assign id2ex_op_jal     = op_jal_r;
    assign id2ex_op_jalr    = op_jalr_r;
    assign id2ex_op_branch  = op_branch_r;
    assign id2ex_bjp_base   = bjp_base_r;
    assign id2ex_bjp_imm    = bjp_imm_r;
    assign id2ex_inst       = inst_r;
    assign id2ex_pc         = pc_r;
    assign id2ex_pc_nxt     = pc_nxt_r;
    assign id2ex_br_tak     = br_tak_r;

    // Buffer privileged info.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            op_mret_r <= 1'b0;
            op_wfi_r  <= 1'b0;
        end
        else begin
            if (pipe_nxt) begin
                op_mret_r <= #UDLY inst_op_mret;
                op_wfi_r  <= #UDLY inst_op_wfi;
            end
        end
    end
    
    assign id2ex_op_mret = op_mret_r;
    assign id2ex_op_wfi  = op_wfi_r;

    // Buffer WB info.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            wb_act_r <= 1'b0;
            wb_idx_r <= 5'b0;
        end
        else begin
            if (pipe_nxt) begin
                wb_act_r <= #UDLY inst_wb_act;
                wb_idx_r <= #UDLY inst_rd_idx;
            end
        end
    end
    
    assign id2ex_wb_act = wb_act_r;
    assign id2ex_wb_idx = wb_idx_r;

    // Buffer exceptions.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            has_excp_r  <= 1'b0;
            acc_fault_r <= 1'b0;
            mis_align_r <= 1'b0;
            ill_inst_r  <= 1'b0;
            env_call_r  <= 1'b0;
            env_break_r <= 1'b0;
        end
        else begin
            if (pipe_nxt) begin
                has_excp_r  <= #UDLY pipe_has_excp
                            | ill_inst | inst_op_ecall | inst_op_ebreak;
                acc_fault_r <= #UDLY pipe_acc_fault;
                mis_align_r <= #UDLY pipe_mis_align;
                ill_inst_r  <= #UDLY ill_inst;
                env_call_r  <= #UDLY inst_op_ecall;
                env_break_r <= #UDLY inst_op_ebreak;
            end
        end
    end

    assign id2ex_has_excp   = has_excp_r;
    assign id2ex_acc_fault  = acc_fault_r;
    assign id2ex_mis_align  = mis_align_r;
    assign id2ex_ill_inst   = ill_inst_r;
    assign id2ex_env_call   = env_call_r;
    assign id2ex_env_break  = env_break_r;
    
    // Forwarding operand indices.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rs1_vld_r <= 1'b0;
            rs2_vld_r <= 1'b0;
            rs1_idx_r <= 5'h0;
            rs2_idx_r <= 5'h0;
        end
        else begin
            if (pipe_nxt) begin
                rs1_vld_r <= #UDLY rs1_vld;
                rs2_vld_r <= #UDLY rs2_vld;
                rs1_idx_r <= #UDLY inst_rs1_idx;
                rs2_idx_r <= #UDLY inst_rs2_idx;
            end
        end
    end
    
    assign id2ex_rs1_vld = rs1_vld_r;
    assign id2ex_rs2_vld = rs2_vld_r;
    assign id2ex_rs1_idx = rs1_idx_r;
    assign id2ex_rs2_idx = rs2_idx_r;
    
    // Read from regfile.
    assign id2rf_ra_idx  = inst_rs1_idx;
    assign id2rf_rb_idx  = inst_rs2_idx;

    // Buffer fence info.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            fencei_r     <= 1'b0;
            fence_r      <= 1'b0;
            fence_pred_r <= 4'b0;
            fence_succ_r <= 4'b0;
        end
        else begin
            if (pipe_nxt) begin
                fence_r      <= #UDLY inst_op_fence;
                fencei_r     <= #UDLY inst_op_fencei;
                if (inst_op_fence) begin
                    fence_pred_r <= #UDLY inst_rv32[27:24];
                    fence_succ_r <= #UDLY inst_rv32[23:20];
                end
            end
        end
    end

    assign fence_inst = fencei_r;
    assign fence_data = fence_r;
    assign fence_pred = fence_pred_r;
    assign fence_succ = fence_succ_r;

    // Output forwarding info before pipeline.
    assign if2bp_fw_act = inst_wb_act;
    assign if2bp_fw_idx = inst_rd_idx;

    // Buffer misprediction status.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            bjp_mis_r <= 1'b0;
        end
        else begin
            bjp_mis_r <= #UDLY bjp_mis;
        end
    end

    assign id_br_flush = bjp_mis_r;

    // Buffer branch states.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            bjp_vld_r  <= 1'b0;
            bjp_addr_r <= {ALEN{1'b0}};
        end
        else begin
            //if (id2ex_vld) begin
                bjp_vld_r  <= #UDLY bjp_vld;
                bjp_addr_r <= #UDLY bjp_addr;
            //end
        end
    end
    
    assign id2if_bjp_vld  = bjp_vld_r;
    assign id2if_bjp_addr = bjp_addr_r;

endmodule

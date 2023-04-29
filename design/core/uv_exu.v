//************************************************************
// See LICENSE for license details.
//
// Module: uv_exu
//
// Designer: Owen
//
// Description:
//      Execution Unit.
//************************************************************

`timescale 1ns / 1ps

module uv_exu
#(
    parameter ALEN = 32,
    parameter ILEN = 32,
    parameter XLEN = 32,
    parameter MLEN = XLEN / 8
)
(
    input                   clk,
    input                   rst_n,
    
    // IDU handshake.
    input                   id2ex_vld,
    output                  id2ex_rdy,
    
    // IDU info.
    input                   id2ex_alu_sgn,
    input                   id2ex_alu_sft,
    input                   id2ex_alu_stl,
    input                   id2ex_alu_add,
    input                   id2ex_alu_sub,
    input                   id2ex_alu_lui,
    input                   id2ex_alu_xor,
    input                   id2ex_alu_or,
    input                   id2ex_alu_and,
    input                   id2ex_alu_slt,
    input  [XLEN-1:0]       id2ex_alu_opa,
    input  [XLEN-1:0]       id2ex_alu_opb,
    input                   id2ex_opa_pc,

    input                   id2ex_op_mul,
    input                   id2ex_op_mix,
    input                   id2ex_op_low,
    input                   id2ex_op_div,
    input                   id2ex_op_rem,
    
    input                   id2ex_csr_rd,
    input                   id2ex_csr_wr,
    input                   id2ex_csr_rs,
    input                   id2ex_csr_rc,
    input                   id2ex_csr_imm,
    input  [11:0]           id2ex_csr_idx,
    input  [XLEN-1:0]       id2ex_csr_val,

    input                   id2ex_op_load,
    input                   id2ex_op_loadu,
    input                   id2ex_op_store,
    input  [MLEN-1:0]       id2ex_ls_mask,
    input  [XLEN-1:0]       id2ex_st_data,
    
    input                   id2ex_op_bjp,
    input                   id2ex_op_beq,
    input                   id2ex_op_bne,
    input                   id2ex_op_blt,
    input                   id2ex_op_bge,
    input                   id2ex_op_jal,
    input                   id2ex_op_jalr,
    input                   id2ex_op_branch,
    input  [ALEN-1:0]       id2ex_bjp_base,
    input  [ALEN-1:0]       id2ex_bjp_imm,
    input  [ILEN-1:0]       id2ex_inst,
    input  [ALEN-1:0]       id2ex_pc,
    input  [ALEN-1:0]       id2ex_pc_nxt,
    input                   id2ex_br_tak,

    input                   id2ex_op_mret,
    input                   id2ex_op_wfi,
    
    input                   id2ex_wb_act,
    input  [4:0]            id2ex_wb_idx,

    input                   id2ex_has_excp,
    input                   id2ex_acc_fault,
    input                   id2ex_mis_align,
    input                   id2ex_ill_inst,
    input                   id2ex_env_call,
    input                   id2ex_env_break,
    
    // CSR reading.
    output                  ex2cs_rd_vld,
    output                  ex2cs_wb_act,
    output [11:0]           ex2cs_rd_idx,
    input  [XLEN-1:0]       ex2cs_rd_data,
    input                   ex2cs_csr_excp,

    // LSU handshake.
    output                  ex2ls_vld,
    input                   ex2ls_rdy,
    
    // LSU info.
    output                  ex2ls_op_load,
    output                  ex2ls_op_loadu,
    output                  ex2ls_op_store,
    output [MLEN-1:0]       ex2ls_ls_mask,
    output [ALEN-1:0]       ex2ls_ld_addr,
    output [ALEN-1:0]       ex2ls_st_addr,
    output [XLEN-1:0]       ex2ls_st_data,

    // Privileged info.
    output                  ex2ls_op_mret,
    output                  ex2ls_op_wfi,
    
    // WB info.
    output                  ex2ls_wb_act,
    output                  ex2ls_wb_vld,
    output [4:0]            ex2ls_wb_idx,
    output [XLEN-1:0]       ex2ls_wb_data,

    // CSR writing.
    output                  ex2ls_csr_vld,
    output [11:0]           ex2ls_csr_idx,
    output [XLEN-1:0]       ex2ls_csr_data,

    // Fetch info.
    output [ALEN-1:0]       ex2ls_inst,
    output [ALEN-1:0]       ex2ls_pc,
    output [ALEN-1:0]       ex2ls_pc_nxt,

    // Excp info.
    output                  ex2ls_has_excp,
    output                  ex2ls_acc_fault,
    output                  ex2ls_mis_align,
    output                  ex2ls_ill_inst,
    output                  ex2ls_env_call,
    output                  ex2ls_env_break,

    // Flush by mispred branch or jump.
    output                  ex_br_flush,

    // Branch info to IFU.
    output                  ex2if_bjp_vld,
    output [ALEN-1:0]       ex2if_bjp_addr,

    // Branch back-pressure to IDU.
    output                  ex2id_br_act,
    output [4:0]            ex2id_br_idx,

    // Flush by trap.
    input                   trap_flush,
    
    // Forwarding info from IDU & LSU.
    input                   id2ex_rs1_vld,
    input                   id2ex_rs2_vld,
    input  [4:0]            id2ex_rs1_idx,
    input  [4:0]            id2ex_rs2_idx,
    
    input                   ls2ex_fw_vld,
    input  [4:0]            ls2ex_fw_idx,
    input  [XLEN-1:0]       ls2ex_fw_data,

    input                   ls2ex_csr_vld,
    input  [11:0]           ls2ex_csr_idx,
    input  [XLEN-1:0]       ls2ex_csr_data,
    
    // Forwarding info to LSU.
    output [4:0]            ex2ls_rs2_idx
);

    localparam UDLY         = 1;
    localparam SFT_DW       = 5;
    //localparam MUL_STAGE  = 0;
    localparam MUL_STAGE    = 3;
    
    // Pipeline control.
    wire                    ex_stall_vld;
    wire                    cs_stall_vld;
    wire                    ls_stall_vld;
    reg                     ex_stall_vld_r;
    reg                     cs_stall_vld_r;
    reg                     ls_stall_vld_r;

    wire                    mul_stall;
    wire                    div_stall;

    wire                    ex_stall;
    wire                    cs_stall;
    wire                    ls_stall;
    wire                    pipe_stall;
    wire                    pipe_start;
    wire                    pipe_flush;
    wire [2:0]              cs_stall_nxt;

    wire                    pipe_pre;
    wire                    pipe_nxt;
    wire                    id2ex_fire;
    wire                    ex2ls_fire;
    wire                    id2ex_real;
    wire                    ex2ls_real;

    reg                     id2ex_fire_p;
    reg                     id2ex_init_p;
    reg                     ex2ls_fire_p;
    reg                     ex2ls_init_p;
    reg                     pipe_stall_p;
    reg                     ex_stall_p;
    reg                     ls_stall_p;
    reg  [2:0]              cs_stall_p;

    // Self forwarding.
    wire                    ex2ex_fw_vld;
    wire [4:0]              ex2ex_fw_idx;
    wire [XLEN-1:0]         ex2ex_fw_data;

    // Input buffer.
    reg                     id2ex_alu_sgn_r;
    reg                     id2ex_alu_sft_r;
    reg                     id2ex_alu_stl_r;
    reg                     id2ex_alu_add_r;
    reg                     id2ex_alu_sub_r;
    reg                     id2ex_alu_lui_r;
    reg                     id2ex_alu_xor_r;
    reg                     id2ex_alu_or_r;
    reg                     id2ex_alu_and_r;
    reg                     id2ex_alu_slt_r;
    reg  [XLEN-1:0]         id2ex_ls_offset_r;
    reg                     id2ex_opa_pc_r;

    reg  [XLEN-1:0]         src_alu_opa_r;
    reg  [XLEN-1:0]         src_alu_opb_r;

    reg                     id2ex_op_mul_r;
    reg                     id2ex_op_mix_r;
    reg                     id2ex_op_low_r;
    reg                     id2ex_op_div_r;
    reg                     id2ex_op_rem_r;

    reg                     id2ex_csr_rd_r;
    reg                     id2ex_csr_wr_r;
    reg                     id2ex_csr_rs_r;
    reg                     id2ex_csr_rc_r;
    reg                     id2ex_csr_imm_r;
    reg  [11:0]             id2ex_csr_idx_r;
    reg  [XLEN-1:0]         id2ex_csr_val_r;

    reg                     id2ex_op_load_r;
    reg                     id2ex_op_loadu_r;
    reg                     id2ex_op_store_r;
    reg  [MLEN-1:0]         id2ex_ls_mask_r;
    reg  [XLEN-1:0]         id2ex_st_data_r;
    reg                     id2ex_op_bjp_r;
    reg                     id2ex_op_beq_r;
    reg                     id2ex_op_bne_r;
    reg                     id2ex_op_blt_r;
    reg                     id2ex_op_bge_r;
    reg                     id2ex_op_jal_r;
    reg                     id2ex_op_jalr_r;
    reg                     id2ex_op_branch_r;
    reg  [ALEN-1:0]         id2ex_bjp_base_r;
    reg  [ALEN-1:0]         id2ex_bjp_imm_r;
    reg  [ILEN-1:0]         id2ex_inst_r;
    reg  [ALEN-1:0]         id2ex_pc_r;
    reg  [ALEN-1:0]         id2ex_pc_nxt_r;
    reg                     id2ex_br_tak_r;

    reg                     id2ex_op_mret_r;
    reg                     id2ex_op_wfi_r;

    reg                     id2ex_wb_act_r;
    reg  [4:0]              id2ex_wb_idx_r;
    reg                     id2ex_rs1_vld_r;
    reg                     id2ex_rs2_vld_r;
    reg  [4:0]              id2ex_rs1_idx_r;
    reg  [4:0]              id2ex_rs2_idx_r;

    reg                     id2ex_has_excp_r;
    reg                     id2ex_acc_fault_r;
    reg                     id2ex_mis_align_r;
    reg                     id2ex_ill_inst_r;
    reg                     id2ex_env_call_r;
    reg                     id2ex_env_break_r;

    reg                     ls2ex_fw_vld_r;
    reg  [4:0]              ls2ex_fw_idx_r;
    reg  [XLEN-1:0]         ls2ex_fw_data_r;

    reg                     ex2ex_fw_vld_r;
    reg  [4:0]              ex2ex_fw_idx_r;
    reg  [XLEN-1:0]         ex2ex_fw_data_r;
    
    // Pipeline sources.
    wire                    pipe_alu_sgn;
    wire                    pipe_alu_sft;
    wire                    pipe_alu_stl;
    wire                    pipe_alu_add;
    wire                    pipe_alu_sub;
    wire                    pipe_alu_lui;
    wire                    pipe_alu_xor;
    wire                    pipe_alu_or;
    wire                    pipe_alu_and;
    wire                    pipe_alu_slt;
    wire [XLEN-1:0]         pipe_alu_opa;
    wire [XLEN-1:0]         pipe_alu_opb;
    wire [XLEN-1:0]         pipe_ls_offset;
    wire                    pipe_opa_pc;

    wire                    pipe_op_mul;
    wire                    pipe_op_mix;
    wire                    pipe_op_low;
    wire                    pipe_op_div;
    wire                    pipe_op_rem;

    wire                    pipe_csr_rd;
    wire                    pipe_csr_wr;
    wire                    pipe_csr_rs;
    wire                    pipe_csr_rc;
    wire                    pipe_csr_imm;
    wire [11:0]             pipe_csr_idx;
    wire [XLEN-1:0]         pipe_csr_val;
    
    wire                    pipe_op_load;
    wire                    pipe_op_loadu;
    wire                    pipe_op_store;
    wire [MLEN-1:0]         pipe_ls_mask;
    wire [XLEN-1:0]         pipe_st_data;
    wire                    pipe_op_bjp;
    wire                    pipe_op_beq;
    wire                    pipe_op_bne;
    wire                    pipe_op_blt;
    wire                    pipe_op_bge;
    wire                    pipe_op_jal;
    wire                    pipe_op_jalr;
    wire                    pipe_op_branch;
    wire [ALEN-1:0]         pipe_bjp_base;
    wire [ALEN-1:0]         pipe_bjp_imm;
    wire [ILEN-1:0]         pipe_inst;
    wire [ALEN-1:0]         pipe_pc;
    wire [ALEN-1:0]         pipe_pc_nxt;
    wire                    pipe_br_tak;

    wire                    pipe_op_mret;
    wire                    pipe_op_wfi;

    wire                    pipe_wb_act;
    wire [4:0]              pipe_wb_idx;
    wire                    pipe_rs1_vld;
    wire                    pipe_rs2_vld;
    wire [4:0]              pipe_rs1_idx;
    wire [4:0]              pipe_rs2_idx;

    wire                    pipe_has_excp;
    wire                    pipe_acc_fault;
    wire                    pipe_mis_align;
    wire                    pipe_ill_inst;
    wire                    pipe_env_call;
    wire                    pipe_env_break;

    wire                    pipe_ls_fw_vld;
    wire [4:0]              pipe_ls_fw_idx;
    wire [XLEN-1:0]         pipe_ls_fw_data;

    wire                    pipe_ex_fw_vld;
    wire [4:0]              pipe_ex_fw_idx;
    wire [XLEN-1:0]         pipe_ex_fw_data;

    wire                    pipe_op_ldst;

    // ALU operands.
    wire [XLEN-1:0]         calc_opa;
    wire [XLEN-1:0]         calc_opb;
    
    // ALU results.
    wire [XLEN-1:0]         alu_res;
    wire                    cmp_eq;
    wire                    cmp_ne;
    wire                    cmp_lt;
    wire                    cmp_ge;

    // MulDiv signals.
    wire                    mul_start;
    wire                    div_start;

    wire                    mul_req_vld;
    wire                    div_req_vld;

    wire                    mul_rsp_vld;
    wire [XLEN-1:0]         mul_rsp_res;
    wire                    div_rsp_vld;
    wire [XLEN-1:0]         div_rsp_res;

    reg                     mul_req_r;
    reg                     div_req_r;
    
    // Branch sources.
    wire [XLEN-1:0]         bjp_base;
    wire [ALEN-1:0]         bjp_offset;

    // Branch results.
    wire                    bjp_eq;
    wire                    bjp_ne;
    wire                    bjp_lt;
    wire                    bjp_ge;
    wire                    bjp_tak;
    wire                    bjp_mis;

    wire                    bjp_vld;
    wire [ALEN-1:0]         bjp_addr;
    
    // Store data.
    wire [XLEN-1:0]         st_data;

    // CSR src data.
    wire [XLEN-1:0]         csr_rs_data;

    // WB data.
    wire [XLEN-1:0]         wb_data;
    wire [XLEN-1:0]         csr_rd_data;
    
    // Forwarding states.
    wire                    fw_rs1_frm_idu;
    wire                    fw_rs2_frm_idu;
    wire                    fw_std_frm_idu;
    wire                    fw_csr_frm_idu;
    wire                    fw_rs1_frm_exu;
    wire                    fw_rs2_frm_exu;
    wire                    fw_std_frm_exu;
    wire                    fw_csr_frm_exu;
    wire                    fw_rs1_frm_lsu;
    wire                    fw_rs2_frm_lsu;
    wire                    fw_std_frm_lsu;
    wire                    fw_csrs_frm_lsu;

    // Handshake registers.
    reg                     ex2ls_vld_r;
    
    // CSR WR registers.
    reg                     csr_wr_vld_r;
    reg  [11:0]             csr_wr_idx_r;
    reg  [XLEN-1:0]         csr_wr_data_r;

    // LS buf registers.
    reg                     op_load_r;
    reg                     op_loadu_r;
    reg                     op_store_r;
    reg  [MLEN-1:0]         ls_mask_r;
    reg  [ALEN-1:0]         ld_addr_r;
    reg  [ALEN-1:0]         st_addr_r;
    reg  [XLEN-1:0]         st_data_r;

    // Privileged buf registers.
    reg                     op_mret_r;
    reg                     op_wfi_r;
    
    // WB buf registers.
    reg                     wb_act_r;
    reg                     wb_vld_r;
    reg  [4:0]              wb_idx_r;
    reg  [XLEN-1:0]         wb_data_r;

    // FW buf registers.
    reg                     br_act_r;
    reg  [4:0]              br_idx_r;
    
    // Branch buf registers.
    reg                     bjp_vld_r;
    reg  [ALEN-1:0]         bjp_addr_r;
    
    // Forwarding buf register.
    reg  [4:0]              rs2_idx_r;

    // Fetch buf registers.
    reg  [ILEN-1:0]         inst_r;
    reg  [ALEN-1:0]         pc_r;
    reg  [ALEN-1:0]         pc_nxt_r;

    // Exception buf registers.
    reg                     has_excp_r;
    reg                     acc_fault_r;
    reg                     mis_align_r;
    reg                     ill_inst_r;
    reg                     env_call_r;
    reg                     env_break_r;

    // Prediction buf register.
    reg                     bjp_mis_r;
    
    // Control pipeline.
    assign ex_stall_vld     = 1'b0;
    assign cs_stall_vld     = ex2ls_vld && csr_wr_vld_r && pipe_csr_rd &&
                              (csr_wr_idx_r == pipe_csr_idx);
    assign ls_stall_vld     = ex2ls_vld && op_load_r && wb_act_r && (
                              ((wb_idx_r == pipe_rs1_idx) && pipe_rs1_vld) ||
                              ((wb_idx_r == pipe_rs2_idx) && pipe_rs2_vld));

    assign mul_stall        = (mul_req_vld | mul_req_r) & (~mul_rsp_vld);
    assign div_stall        = (div_req_vld | div_req_r) & (~div_rsp_vld);

    assign ex_stall         = mul_stall | div_stall;
    assign cs_stall         = (cs_stall_vld | cs_stall_vld_r) & ex2ls_rdy;
    assign ls_stall         = (ls_stall_vld | ls_stall_vld_r) & ex2ls_rdy;

    assign pipe_stall       = ls_stall | ex_stall | (|cs_stall_nxt);
    assign pipe_start       = id2ex_vld & ex2ls_rdy
                            & (~ls_stall) & (~(|cs_stall_nxt)) & (~pipe_flush);
    assign pipe_flush       = ex_br_flush | trap_flush;
    assign cs_stall_nxt     = {cs_stall_p[1:0], cs_stall};

    // Handshake: rsp to IDU.
    assign pipe_pre         = id2ex_vld & (~pipe_flush);
    assign pipe_nxt         = pipe_pre  & (~pipe_stall);
    assign id2ex_rdy        = ex2ls_rdy & (~pipe_stall);
    assign id2ex_fire       = id2ex_vld & id2ex_rdy & (~pipe_flush);
    assign id2ex_real       = id2ex_fire_p | id2ex_init_p;
    
    // Handshake: req to LSU.
    assign ex2ls_vld        = ex2ls_vld_r & (~trap_flush) & (~ex_stall_p)
                            & (~(|ls_stall_p))
                            & (~(|cs_stall_p));
    assign ex2ls_fire       = ex2ls_vld & ex2ls_rdy;
    assign ex2ls_real       = ex2ls_fire_p | ex2ls_init_p;

    // Fowrding to self.
    assign ex2ex_fw_vld     = wb_vld_r;
    assign ex2ex_fw_idx     = wb_idx_r;
    assign ex2ex_fw_data    = wb_data_r;

    // Select pipeline sources.
    assign pipe_alu_sgn     = id2ex_real ? id2ex_alu_sgn    : id2ex_alu_sgn_r;
    assign pipe_alu_sft     = id2ex_real ? id2ex_alu_sft    : id2ex_alu_sft_r;
    assign pipe_alu_stl     = id2ex_real ? id2ex_alu_stl    : id2ex_alu_stl_r;
    assign pipe_alu_add     = id2ex_real ? id2ex_alu_add    : id2ex_alu_add_r;
    assign pipe_alu_sub     = id2ex_real ? id2ex_alu_sub    : id2ex_alu_sub_r;
    assign pipe_alu_lui     = id2ex_real ? id2ex_alu_lui    : id2ex_alu_lui_r;
    assign pipe_alu_xor     = id2ex_real ? id2ex_alu_xor    : id2ex_alu_xor_r;
    assign pipe_alu_or      = id2ex_real ? id2ex_alu_or     : id2ex_alu_or_r;
    assign pipe_alu_and     = id2ex_real ? id2ex_alu_and    : id2ex_alu_and_r;
    assign pipe_alu_slt     = id2ex_real ? id2ex_alu_slt    : id2ex_alu_slt_r;
    assign pipe_ls_offset   = id2ex_real ? id2ex_alu_opb    : id2ex_ls_offset_r;
    assign pipe_opa_pc      = id2ex_real ? id2ex_opa_pc     : id2ex_opa_pc_r;

    assign pipe_alu_opa     = id2ex_real ? id2ex_alu_opa    : src_alu_opa_r;
    assign pipe_alu_opb     = id2ex_real ? id2ex_alu_opb    : src_alu_opb_r;

    assign pipe_op_mul      = id2ex_real ? id2ex_op_mul     : id2ex_op_mul_r;
    assign pipe_op_mix      = id2ex_real ? id2ex_op_mix     : id2ex_op_mix_r;
    assign pipe_op_low      = id2ex_real ? id2ex_op_low     : id2ex_op_low_r;
    assign pipe_op_div      = id2ex_real ? id2ex_op_div     : id2ex_op_div_r;
    assign pipe_op_rem      = id2ex_real ? id2ex_op_rem     : id2ex_op_rem_r;

    assign pipe_csr_rd      = id2ex_real ? id2ex_csr_rd     : id2ex_csr_rd_r;
    assign pipe_csr_wr      = id2ex_real ? id2ex_csr_wr     : id2ex_csr_wr_r;
    assign pipe_csr_rs      = id2ex_real ? id2ex_csr_rs     : id2ex_csr_rs_r;
    assign pipe_csr_rc      = id2ex_real ? id2ex_csr_rc     : id2ex_csr_rc_r;
    assign pipe_csr_imm     = id2ex_real ? id2ex_csr_imm    : id2ex_csr_imm_r;
    assign pipe_csr_idx     = id2ex_real ? id2ex_csr_idx    : id2ex_csr_idx_r;
    assign pipe_csr_val     = id2ex_real ? id2ex_csr_val    : id2ex_csr_val_r;

    assign pipe_op_load     = id2ex_real ? id2ex_op_load    : id2ex_op_load_r;
    assign pipe_op_loadu    = id2ex_real ? id2ex_op_loadu   : id2ex_op_loadu_r;
    assign pipe_op_store    = id2ex_real ? id2ex_op_store   : id2ex_op_store_r;
    assign pipe_ls_mask     = id2ex_real ? id2ex_ls_mask    : id2ex_ls_mask_r;
    assign pipe_st_data     = id2ex_real ? id2ex_st_data    : id2ex_st_data_r;
    assign pipe_op_bjp      = id2ex_real ? id2ex_op_bjp     : id2ex_op_bjp_r;
    assign pipe_op_beq      = id2ex_real ? id2ex_op_beq     : id2ex_op_beq_r;
    assign pipe_op_bne      = id2ex_real ? id2ex_op_bne     : id2ex_op_bne_r;
    assign pipe_op_blt      = id2ex_real ? id2ex_op_blt     : id2ex_op_blt_r;
    assign pipe_op_bge      = id2ex_real ? id2ex_op_bge     : id2ex_op_bge_r;
    assign pipe_op_jal      = id2ex_real ? id2ex_op_jal     : id2ex_op_jal_r;
    assign pipe_op_jalr     = id2ex_real ? id2ex_op_jalr    : id2ex_op_jalr_r;
    assign pipe_op_branch   = id2ex_real ? id2ex_op_branch  : id2ex_op_branch_r;
    assign pipe_bjp_base    = id2ex_real ? id2ex_bjp_base   : id2ex_bjp_base_r;
    assign pipe_bjp_imm     = id2ex_real ? id2ex_bjp_imm    : id2ex_bjp_imm_r;
    assign pipe_inst        = id2ex_real ? id2ex_inst       : id2ex_inst_r;
    assign pipe_pc          = id2ex_real ? id2ex_pc         : id2ex_pc_r;
    assign pipe_pc_nxt      = id2ex_real ? id2ex_pc_nxt     : id2ex_pc_nxt_r;
    assign pipe_br_tak      = id2ex_real ? id2ex_br_tak     : id2ex_br_tak_r;

    assign pipe_op_mret     = id2ex_real ? id2ex_op_mret    : id2ex_op_mret_r;
    assign pipe_op_wfi      = id2ex_real ? id2ex_op_wfi     : id2ex_op_wfi_r;

    assign pipe_wb_act      = id2ex_real ? id2ex_wb_act     : id2ex_wb_act_r;
    assign pipe_wb_idx      = id2ex_real ? id2ex_wb_idx     : id2ex_wb_idx_r;
    assign pipe_rs1_vld     = id2ex_real ? id2ex_rs1_vld    : id2ex_rs1_vld_r;
    assign pipe_rs2_vld     = id2ex_real ? id2ex_rs2_vld    : id2ex_rs2_vld_r;
    assign pipe_rs1_idx     = id2ex_real ? id2ex_rs1_idx    : id2ex_rs1_idx_r;
    assign pipe_rs2_idx     = id2ex_real ? id2ex_rs2_idx    : id2ex_rs2_idx_r;

    assign pipe_has_excp    = id2ex_real ? id2ex_has_excp   : id2ex_has_excp_r;
    assign pipe_acc_fault   = id2ex_real ? id2ex_acc_fault  : id2ex_acc_fault_r;
    assign pipe_mis_align   = id2ex_real ? id2ex_mis_align  : id2ex_mis_align_r;
    assign pipe_ill_inst    = id2ex_real ? id2ex_ill_inst   : id2ex_ill_inst_r;
    assign pipe_env_call    = id2ex_real ? id2ex_env_call   : id2ex_env_call_r;
    assign pipe_env_break   = id2ex_real ? id2ex_env_break  : id2ex_env_break_r;

    assign pipe_ls_fw_vld   = ex2ls_real ? ls2ex_fw_vld     : ls2ex_fw_vld_r;
    assign pipe_ls_fw_idx   = ex2ls_real ? ls2ex_fw_idx     : ls2ex_fw_idx_r;
    assign pipe_ls_fw_data  = ex2ls_real ? ls2ex_fw_data    : ls2ex_fw_data_r;

    assign pipe_ex_fw_vld   = ex2ls_real ? ex2ex_fw_vld     : ex2ex_fw_vld_r;
    assign pipe_ex_fw_idx   = ex2ls_real ? ex2ex_fw_idx     : ex2ex_fw_idx_r;
    assign pipe_ex_fw_data  = ex2ls_real ? ex2ex_fw_data    : ex2ex_fw_data_r;

    assign pipe_op_ldst     = pipe_op_load | pipe_op_store;

    // Get CSR source data.
    assign csr_rs_data      = pipe_csr_imm   ? pipe_csr_val
                            : fw_rs1_frm_exu ? wb_data_r
                            : fw_rs1_frm_lsu ? ls2ex_fw_data
                            : pipe_csr_val;

    // Get write-back data.
    assign wb_data          = pipe_csr_rd ? csr_rd_data
                            : pipe_op_mul ? mul_rsp_res
                            : pipe_op_div ? div_rsp_res
                            : alu_res;
    assign csr_rd_data      = fw_csr_frm_exu ? csr_wr_data_r
                            : fw_csr_frm_lsu ? ls2ex_csr_data
                            : ex2cs_rd_data;
    
    // Get branch base.
    assign bjp_base         = (pipe_op_jalr & fw_rs1_frm_exu) ? pipe_ex_fw_data
                            : (pipe_op_jalr & fw_rs1_frm_lsu) ? pipe_ls_fw_data
                            : (pipe_op_jalr & fw_rs1_frm_idu) ? pipe_bjp_base
                            : pipe_pc;
    assign bjp_offset       = (pipe_op_jal | pipe_op_jalr | bjp_tak) ? pipe_bjp_imm
                            : {{(ALEN-3){1'b0}}, 3'd4};

    // Summary branch states.
    assign bjp_eq           = pipe_op_beq & cmp_eq;
    assign bjp_ne           = pipe_op_bne & cmp_ne;
    assign bjp_lt           = pipe_op_blt & cmp_lt;
    assign bjp_ge           = pipe_op_bge & cmp_ge;

    assign bjp_tak          = bjp_eq | bjp_ne | bjp_lt | bjp_ge;
    assign bjp_mis          = id2ex_fire && ((bjp_tak  ^  pipe_br_tak)
                                         ||  (bjp_addr != pipe_pc_nxt));
    
    assign bjp_vld          = bjp_mis;
    assign bjp_addr         = bjp_base + bjp_offset;
    
    // Get forwarding states.
    assign fw_rs1_frm_exu   = pipe_ex_fw_vld && (pipe_ex_fw_idx == pipe_rs1_idx) && pipe_rs1_vld;
    assign fw_rs2_frm_exu   = pipe_ex_fw_vld && (pipe_ex_fw_idx == pipe_rs2_idx) && pipe_rs2_vld;
    assign fw_std_frm_exu   = pipe_ex_fw_vld && (pipe_ex_fw_idx == pipe_rs2_idx) && pipe_op_store;
    assign fw_csr_frm_exu   = csr_wr_vld_r  && (csr_wr_idx_r  == pipe_csr_idx) && pipe_csr_rd;
    assign fw_rs1_frm_lsu   = pipe_ls_fw_vld && (pipe_ls_fw_idx == pipe_rs1_idx) && pipe_rs1_vld;
    assign fw_rs2_frm_lsu   = pipe_ls_fw_vld && (pipe_ls_fw_idx == pipe_rs2_idx) && pipe_rs2_vld;
    assign fw_std_frm_lsu   = pipe_ls_fw_vld && (pipe_ls_fw_idx == pipe_rs2_idx) && pipe_op_store;
    assign fw_csr_frm_lsu   = ls2ex_csr_vld && (ls2ex_csr_idx == pipe_csr_idx) && pipe_csr_rd;
    assign fw_rs1_frm_idu   = ~(fw_rs1_frm_exu | fw_rs1_frm_lsu);
    assign fw_rs2_frm_idu   = ~(fw_rs2_frm_exu | fw_rs2_frm_lsu);
    assign fw_std_frm_idu   = ~(fw_std_frm_exu | fw_std_frm_lsu);
    assign fw_csr_frm_idu   = ~(fw_csr_frm_exu | fw_csr_frm_lsu);
    
    // Get storing data.
    assign st_data          = fw_std_frm_exu ? wb_data_r
                            : fw_std_frm_lsu ? ls2ex_fw_data
                            : pipe_st_data;

    // Buffer handshake firing.
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
            ex2ls_fire_p <= 1'b0;
        end
        else begin
            ex2ls_fire_p <= #UDLY ex2ls_fire;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            ex2ls_init_p <= 1'b1;
        end
        else begin
            ex2ls_init_p <= #UDLY ~ex2ls_vld;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            ex2ls_vld_r <= 1'b0;
        end
        else begin
            if (pipe_pre) begin
                ex2ls_vld_r <= #UDLY 1'b1;
            end
            else if (ex2ls_rdy | pipe_flush) begin
                ex2ls_vld_r <= #UDLY 1'b0;
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

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            ex_stall_p <= 1'b0;
        end
        else begin
            if (pipe_flush) begin
                ex_stall_p <= #UDLY 1'b0;
            end
            else begin
                ex_stall_p <= #UDLY ex_stall;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            ls_stall_vld_r <= 1'b0;
        end
        else begin
            if (ls_stall_vld & (~ex2ls_rdy)) begin
                ls_stall_vld_r <= #UDLY 1'b1;
            end
            else if (ex2ls_rdy) begin
                ls_stall_vld_r <= #UDLY 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            ls_stall_p <= 1'b0;
        end
        else begin
            if (pipe_flush) begin
                ls_stall_p <= #UDLY 1'b0;
            end
            else begin
                ls_stall_p <= #UDLY ls_stall;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            cs_stall_vld_r <= 1'b0;
        end
        else begin
            if (cs_stall_vld & (~ex2ls_rdy)) begin
                cs_stall_vld_r <= #UDLY 1'b1;
            end
            else if (ex2ls_rdy) begin
                cs_stall_vld_r <= #UDLY 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            cs_stall_p <= 3'b0;
        end
        else begin
            if (pipe_flush) begin
                cs_stall_p <= #UDLY 1'b0;
            end
            else begin
                cs_stall_p <= #UDLY cs_stall_nxt;
            end
        end
    end

    // Buffer input.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            id2ex_alu_sgn_r   <= 1'b0;
            id2ex_alu_sft_r   <= 1'b0;
            id2ex_alu_stl_r   <= 1'b0;
            id2ex_alu_add_r   <= 1'b0;
            id2ex_alu_sub_r   <= 1'b0;
            id2ex_alu_lui_r   <= 1'b0;
            id2ex_alu_xor_r   <= 1'b0;
            id2ex_alu_or_r    <= 1'b0;
            id2ex_alu_and_r   <= 1'b0;
            id2ex_alu_slt_r   <= 1'b0;
            id2ex_ls_offset_r <= {XLEN{1'b0}};
            id2ex_opa_pc_r    <= 1'b0;
            id2ex_op_mul_r    <= 1'b0;
            id2ex_op_mix_r    <= 1'b0;
            id2ex_op_low_r    <= 1'b0;
            id2ex_op_div_r    <= 1'b0;
            id2ex_op_rem_r    <= 1'b0;
            id2ex_csr_rd_r    <= 1'b0;
            id2ex_csr_wr_r    <= 1'b0;
            id2ex_csr_rs_r    <= 1'b0;
            id2ex_csr_rc_r    <= 1'b0;
            id2ex_csr_imm_r   <= 1'b0;
            id2ex_csr_idx_r   <= 12'd0;
            id2ex_csr_val_r   <= {XLEN{1'b0}};
            id2ex_op_load_r   <= 1'b0;
            id2ex_op_loadu_r  <= 1'b0;
            id2ex_op_store_r  <= 1'b0;
            id2ex_ls_mask_r   <= {MLEN{1'b0}};
            id2ex_st_data_r   <= {XLEN{1'b0}};
            id2ex_op_bjp_r    <= 1'b0;
            id2ex_op_beq_r    <= 1'b0;
            id2ex_op_bne_r    <= 1'b0;
            id2ex_op_blt_r    <= 1'b0;
            id2ex_op_bge_r    <= 1'b0;
            id2ex_op_jal_r    <= 1'b0;
            id2ex_op_jalr_r   <= 1'b0;
            id2ex_op_branch_r <= 1'b0;
            id2ex_bjp_base_r  <= {ALEN{1'b0}};
            id2ex_bjp_imm_r   <= {ALEN{1'b0}};
            id2ex_op_mret_r   <= 1'b0;
            id2ex_op_wfi_r    <= 1'b0;
            id2ex_inst_r      <= {ILEN{1'b0}};
            id2ex_pc_r        <= {ALEN{1'b0}};
            id2ex_pc_nxt_r    <= {ALEN{1'b0}};
            id2ex_br_tak_r    <= 1'b0;
            id2ex_wb_act_r    <= 1'b0;
            id2ex_wb_idx_r    <= 5'b0;
            id2ex_rs1_vld_r   <= 1'b0;
            id2ex_rs2_vld_r   <= 1'b0;
            id2ex_rs1_idx_r   <= 5'b0;
            id2ex_rs2_idx_r   <= 5'b0;
            id2ex_has_excp_r  <= 1'b0;
            id2ex_acc_fault_r <= 1'b0;
            id2ex_mis_align_r <= 1'b0;
            id2ex_ill_inst_r  <= 1'b0;
            id2ex_env_call_r  <= 1'b0;
            id2ex_env_break_r <= 1'b0;
        end
        else begin
            if (id2ex_real) begin
                id2ex_alu_sgn_r   <= #UDLY id2ex_alu_sgn;
                id2ex_alu_sft_r   <= #UDLY id2ex_alu_sft;
                id2ex_alu_stl_r   <= #UDLY id2ex_alu_stl;
                id2ex_alu_add_r   <= #UDLY id2ex_alu_add;
                id2ex_alu_sub_r   <= #UDLY id2ex_alu_sub;
                id2ex_alu_lui_r   <= #UDLY id2ex_alu_lui;
                id2ex_alu_xor_r   <= #UDLY id2ex_alu_xor;
                id2ex_alu_or_r    <= #UDLY id2ex_alu_or;
                id2ex_alu_and_r   <= #UDLY id2ex_alu_and;
                id2ex_alu_slt_r   <= #UDLY id2ex_alu_slt;
                id2ex_ls_offset_r <= #UDLY id2ex_alu_opb;
                id2ex_opa_pc_r    <= #UDLY id2ex_opa_pc;
                id2ex_op_mul_r    <= #UDLY id2ex_op_mul;
                id2ex_op_mix_r    <= #UDLY id2ex_op_mix;
                id2ex_op_low_r    <= #UDLY id2ex_op_low;
                id2ex_op_div_r    <= #UDLY id2ex_op_div;
                id2ex_op_rem_r    <= #UDLY id2ex_op_rem;
                id2ex_csr_rd_r    <= #UDLY id2ex_csr_rd;
                id2ex_csr_wr_r    <= #UDLY id2ex_csr_wr;
                id2ex_csr_rs_r    <= #UDLY id2ex_csr_rs;
                id2ex_csr_rc_r    <= #UDLY id2ex_csr_rc;
                id2ex_csr_imm_r   <= #UDLY id2ex_csr_imm;
                id2ex_csr_idx_r   <= #UDLY id2ex_csr_idx;
                id2ex_csr_val_r   <= #UDLY id2ex_csr_val;
                id2ex_op_load_r   <= #UDLY id2ex_op_load;
                id2ex_op_loadu_r  <= #UDLY id2ex_op_loadu;
                id2ex_op_store_r  <= #UDLY id2ex_op_store;
                id2ex_ls_mask_r   <= #UDLY id2ex_ls_mask;
                id2ex_st_data_r   <= #UDLY id2ex_st_data;
                id2ex_op_bjp_r    <= #UDLY id2ex_op_bjp;
                id2ex_op_beq_r    <= #UDLY id2ex_op_beq;
                id2ex_op_bne_r    <= #UDLY id2ex_op_bne;
                id2ex_op_blt_r    <= #UDLY id2ex_op_blt;
                id2ex_op_bge_r    <= #UDLY id2ex_op_bge;
                id2ex_op_jal_r    <= #UDLY id2ex_op_jal;
                id2ex_op_jalr_r   <= #UDLY id2ex_op_jalr;
                id2ex_op_branch_r <= #UDLY id2ex_op_branch;
                id2ex_bjp_base_r  <= #UDLY id2ex_bjp_base;
                id2ex_bjp_imm_r   <= #UDLY id2ex_bjp_imm;
                id2ex_op_mret_r   <= #UDLY id2ex_op_mret;
                id2ex_op_wfi_r    <= #UDLY id2ex_op_wfi;
                id2ex_inst_r      <= #UDLY id2ex_inst;
                id2ex_pc_r        <= #UDLY id2ex_pc;
                id2ex_pc_nxt_r    <= #UDLY id2ex_pc_nxt;
                id2ex_br_tak_r    <= #UDLY id2ex_br_tak;
                id2ex_wb_act_r    <= #UDLY id2ex_wb_act;
                id2ex_wb_idx_r    <= #UDLY id2ex_wb_idx;
                id2ex_rs1_vld_r   <= #UDLY id2ex_rs1_vld;
                id2ex_rs2_vld_r   <= #UDLY id2ex_rs2_vld;
                id2ex_rs1_idx_r   <= #UDLY id2ex_rs1_idx;
                id2ex_rs2_idx_r   <= #UDLY id2ex_rs2_idx;
                id2ex_has_excp_r  <= #UDLY id2ex_has_excp;
                id2ex_acc_fault_r <= #UDLY id2ex_acc_fault;
                id2ex_mis_align_r <= #UDLY id2ex_mis_align;
                id2ex_ill_inst_r  <= #UDLY id2ex_ill_inst;
                id2ex_env_call_r  <= #UDLY id2ex_env_call;
                id2ex_env_break_r <= #UDLY id2ex_env_break;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            ls2ex_fw_vld_r    <= 1'b0;
            ls2ex_fw_idx_r    <= 5'b0;
            ls2ex_fw_data_r   <= {XLEN{1'b0}};
            ex2ex_fw_vld_r    <= 1'b0;
            ex2ex_fw_idx_r    <= 5'b0;
            ex2ex_fw_data_r   <= {XLEN{1'b0}};
        end
        else begin
            if (ex2ls_real) begin
                ls2ex_fw_vld_r    <= #UDLY ls2ex_fw_vld;
                ls2ex_fw_idx_r    <= #UDLY ls2ex_fw_idx;
                ls2ex_fw_data_r   <= #UDLY ls2ex_fw_data;
                ex2ex_fw_vld_r    <= #UDLY ex2ex_fw_vld;
                ex2ex_fw_idx_r    <= #UDLY ex2ex_fw_idx;
                ex2ex_fw_data_r   <= #UDLY ex2ex_fw_data;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            src_alu_opa_r <= {XLEN{1'b0}};
        end
        else begin
            if (fw_rs1_frm_exu) begin
                src_alu_opa_r <= #UDLY pipe_ex_fw_data;
            end
            else if (fw_rs1_frm_lsu) begin
                src_alu_opa_r <= #UDLY pipe_ls_fw_data;
            end
            else if (id2ex_real) begin
                src_alu_opa_r <= #UDLY id2ex_alu_opa;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            src_alu_opb_r <= {XLEN{1'b0}};
        end
        else begin
            if (fw_rs2_frm_exu) begin
                src_alu_opb_r <= #UDLY pipe_ex_fw_data;
            end
            else if (fw_rs2_frm_lsu) begin
                src_alu_opb_r <= #UDLY pipe_ls_fw_data;
            end
            else if (id2ex_real) begin
                src_alu_opb_r <= #UDLY id2ex_alu_opb;
            end
        end
    end

    // Send CSR reading request.
    assign ex2cs_rd_vld = pipe_nxt & (~(|cs_stall_nxt)) ? pipe_csr_rd : 1'b0;
    assign ex2cs_wb_act = pipe_csr_wr;
    assign ex2cs_rd_idx = pipe_csr_idx;

    // Buffer load-store state.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            op_load_r  <= 1'b0;
            op_loadu_r <= 1'b0;
            op_store_r <= 1'b0;
            ls_mask_r  <= {MLEN{1'b0}};
            ld_addr_r  <= {XLEN{1'b0}};
            st_addr_r  <= {XLEN{1'b0}};
            st_data_r  <= {XLEN{1'b0}};
        end
        else begin
            if (pipe_nxt) begin
                op_load_r  <= #UDLY pipe_op_load;
                op_loadu_r <= #UDLY pipe_op_loadu;
                op_store_r <= #UDLY pipe_op_store;
                ls_mask_r  <= #UDLY pipe_ls_mask;
                if (pipe_op_load) begin
                    ld_addr_r <= #UDLY alu_res;
                end
                if (pipe_op_store) begin
                    st_addr_r <= #UDLY alu_res;
                    st_data_r <= #UDLY st_data;
                end
            end
        end
    end
    
    assign ex2ls_op_load  = op_load_r;
    assign ex2ls_op_loadu = op_loadu_r;
    assign ex2ls_op_store = op_store_r;
    assign ex2ls_ls_mask  = ls_mask_r;
    assign ex2ls_ld_addr  = ld_addr_r;
    assign ex2ls_st_addr  = st_addr_r;
    assign ex2ls_st_data  = st_data_r;

    // Buffer privileged states.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            op_mret_r <= 1'b0;
            op_wfi_r  <= 1'b0;
        end
        else begin
            if (pipe_nxt) begin
                op_mret_r <= #UDLY pipe_op_mret;
                op_wfi_r  <= #UDLY pipe_op_wfi;
            end
        end
    end

    assign ex2ls_op_mret = op_mret_r;
    assign ex2ls_op_wfi  = op_wfi_r;
    
    // Buffer write-back states.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            wb_vld_r  <= 1'b0;
            wb_data_r <= {XLEN{1'b0}};
        end
        else begin
            if (pipe_nxt & pipe_wb_act & (~pipe_op_ldst)) begin
                wb_vld_r  <= #UDLY 1'b1;
                wb_data_r <= #UDLY wb_data;
            end
            else begin
                wb_vld_r  <= #UDLY 1'b0;
            end
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            wb_act_r <= 1'b0;
            wb_idx_r <= 5'b0;
        end
        else begin
            if (pipe_nxt) begin
                wb_act_r <= #UDLY pipe_wb_act;
                if (pipe_wb_act) begin
                    wb_idx_r <= #UDLY pipe_wb_idx;
                end
            end
        end
    end
    
    assign ex2ls_wb_act  = wb_act_r;
    assign ex2ls_wb_vld  = wb_vld_r;
    assign ex2ls_wb_idx  = wb_idx_r;
    assign ex2ls_wb_data = wb_data_r;

    // Buffer branch states.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            br_act_r <= 1'b0;
            br_idx_r <= 5'b0;
        end
        else begin
            if (pipe_pre) begin
                br_act_r <= #UDLY pipe_wb_act;
                br_idx_r <= #UDLY pipe_wb_idx;
            end
        end
    end

    assign ex2id_br_act  = br_act_r;
    assign ex2id_br_idx  = br_idx_r;

    // Buffer CSR written info.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            csr_wr_vld_r  <= 1'b0;
            csr_wr_idx_r  <= 12'b0;
            csr_wr_data_r <= {XLEN{1'b0}};
        end
        else begin
            if (pipe_nxt) begin
                csr_wr_vld_r  <= #UDLY pipe_csr_wr;
                csr_wr_idx_r  <= #UDLY pipe_csr_idx;
                csr_wr_data_r <= #UDLY pipe_csr_rs ? (csr_rd_data | csr_rs_data)
                                     : pipe_csr_rc ? (csr_rd_data & (~csr_rs_data))
                                     : csr_rs_data;
            end
            else begin
                csr_wr_vld_r  <= #UDLY 1'b0;
            end
        end
    end

    assign ex2ls_csr_vld  = csr_wr_vld_r;
    assign ex2ls_csr_idx  = csr_wr_idx_r;
    assign ex2ls_csr_data = csr_wr_data_r;
    
    // Buffer fetch info.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            inst_r   <= {ILEN{1'b0}};
            pc_r     <= {ALEN{1'b0}};
            pc_nxt_r <= {ALEN{1'b0}};
        end
        else begin
            if (pipe_nxt) begin
                inst_r   <= #UDLY pipe_inst;
                pc_r     <= #UDLY pipe_pc;
                pc_nxt_r <= #UDLY pipe_op_bjp ? bjp_addr : pipe_pc_nxt;
            end
        end
    end

    assign ex2ls_inst   = inst_r;
    assign ex2ls_pc     = pc_r;
    assign ex2ls_pc_nxt = pc_nxt_r;

    // Buffer exception info.
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
                            | ((ex2cs_rd_vld | ex2cs_wb_act) & ex2cs_csr_excp);
                acc_fault_r <= #UDLY pipe_acc_fault;
                mis_align_r <= #UDLY pipe_mis_align;
                ill_inst_r  <= #UDLY pipe_ill_inst
                            | ((ex2cs_rd_vld | ex2cs_wb_act) & ex2cs_csr_excp);
                env_call_r  <= #UDLY pipe_env_call;
                env_break_r <= #UDLY pipe_env_break;
            end
        end
    end

    assign ex2ls_has_excp   = has_excp_r;
    assign ex2ls_acc_fault  = acc_fault_r;
    assign ex2ls_mis_align  = mis_align_r;
    assign ex2ls_ill_inst   = ill_inst_r;
    assign ex2ls_env_call   = env_call_r;
    assign ex2ls_env_break  = env_break_r;
    
    // Buffer misprediction status.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            bjp_mis_r <= 1'b0;
        end
        else begin
            bjp_mis_r <= #UDLY bjp_mis;
        end
    end

    assign ex_br_flush = bjp_mis_r;

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
    
    assign ex2if_bjp_vld  = bjp_vld_r;
    assign ex2if_bjp_addr = bjp_addr_r;

    // Buffer forwarding info.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rs2_idx_r <= 5'b0;
        end
        else begin
            if (pipe_nxt) begin
                rs2_idx_r <= #UDLY pipe_rs2_idx;
            end
        end
    end

    assign ex2ls_rs2_idx = rs2_idx_r;
    
    // Get ALU operands from decoding & forwarding.
    assign calc_opa     = pipe_opa_pc    ? pipe_pc
                        : fw_rs1_frm_exu ? pipe_ex_fw_data
                        : fw_rs1_frm_lsu ? pipe_ls_fw_data
                        : pipe_alu_opa;
    assign calc_opb     = (pipe_op_load  | pipe_op_store) ? pipe_ls_offset
                        : fw_rs2_frm_exu ? pipe_ex_fw_data
                        : fw_rs2_frm_lsu ? pipe_ls_fw_data
                        : pipe_alu_opb;
 
    // MulDiv control.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            mul_req_r <= 1'b0;
        end
        else begin
            if (pipe_flush) begin
                mul_req_r <= #UDLY 1'b0;
            end
            else if (mul_rsp_vld) begin
                mul_req_r <= #UDLY 1'b0;
            end
            else if (mul_start) begin
                mul_req_r <= #UDLY 1'b1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            div_req_r <= 1'b0;
        end
        else begin
            if (pipe_flush) begin
                div_req_r <= #UDLY 1'b0;
            end
            else if (div_rsp_vld) begin
                div_req_r <= #UDLY 1'b0;
            end
            else if (div_start) begin
                div_req_r <= #UDLY 1'b1;
            end
        end
    end

    assign mul_start   = pipe_start & pipe_op_mul;
    assign div_start   = pipe_start & pipe_op_div;
    assign mul_req_vld = mul_start & (~mul_req_r);
    assign div_req_vld = div_start & (~div_req_r);

    // ALU inst
    uv_alu
    #(
        .ALU_DW         ( XLEN              ),
        .SFT_DW         ( SFT_DW            )
    )
    u_alu
    (
        .clk            ( clk               ),
        .rst_n          ( rst_n             ),
        
        // If signed for shifter & adder
        .alu_sgn        ( pipe_alu_sgn      ),
        // Shift
        .alu_sft        ( pipe_alu_sft      ),
        .alu_stl        ( pipe_alu_stl      ),
        // Arithmetic
        .alu_add        ( pipe_alu_add      ),
        .alu_sub        ( pipe_alu_sub      ),
        .alu_lui        ( pipe_alu_lui      ),
        // Logical
        .alu_xor        ( pipe_alu_xor      ),
        .alu_or         ( pipe_alu_or       ),
        .alu_and        ( pipe_alu_and      ),
        // Compare
        .alu_slt        ( pipe_alu_slt      ),
        
        // ALU oprands
        .alu_opa        ( calc_opa          ),
        .alu_opb        ( calc_opb          ),
        .alu_res        ( alu_res           ),
        
        // CMP results
        .cmp_eq         ( cmp_eq            ),
        .cmp_ne         ( cmp_ne            ),
        .cmp_lt         ( cmp_lt            ),
        .cmp_ge         ( cmp_ge            )
    );

    uv_mul
    #(
        .MUL_DW         ( XLEN              ),
        .PIPE_STAGE     ( MUL_STAGE         )
    )
    u_mul
    (
        .clk            ( clk               ),
        .rst_n          ( rst_n             ),
        
        .req_vld        ( mul_req_vld       ),
        .req_sgn        ( pipe_alu_sgn      ),
        .req_mix        ( pipe_op_mix       ),
        .req_low        ( pipe_op_low       ),
        
        .req_opa        ( calc_opa          ),
        .req_opb        ( calc_opb          ),

        .rsp_vld        ( mul_rsp_vld       ),
        .rsp_res        ( mul_rsp_res       )
    );

    uv_div
    #(
        .DIV_DW         ( XLEN              )
    )
    u_div
    (
        .clk            ( clk               ),
        .rst_n          ( rst_n             ),
        
        .req_rdy        (                   ),
        .req_vld        ( div_req_vld       ),
        .req_sgn        ( pipe_alu_sgn      ),
        .req_rem        ( pipe_op_rem       ),

        .req_opa        ( calc_opa          ),
        .req_opb        ( calc_opb          ),

        .rsp_vld        ( div_rsp_vld       ),
        .rsp_res        ( div_rsp_res       )
    );
    
endmodule

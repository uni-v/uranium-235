//************************************************************
// See LICENSE for license details.
//
// Module: uv_ucore
//
// Designer: Owen
//
// Description:
//      Uni-V Micro Core.
//************************************************************

`timescale 1ns / 1ps

module uv_ucore
#(
    parameter ARCH_ID           = 64'h235,
    parameter IMPL_ID           = 1,
    parameter HART_ID           = 0,
    parameter VENDOR_ID         = 0,
    parameter ALEN              = 32,
    parameter ILEN              = 32,
    parameter XLEN              = 32,
    parameter MLEN              = XLEN / 8
)
(
    input                       clk,
    input                       rst_n,

    // Reset vector from system.
    input  [ALEN-1:0]           rst_vec,
    
    // Inst fetching access.
    output                      if_req_vld,
    input                       if_req_rdy,
    output [ALEN-1:0]           if_req_addr,

    input                       if_rsp_vld,
    output                      if_rsp_rdy,
    input  [1:0]                if_rsp_excp,
    input  [ILEN-1:0]           if_rsp_data,
    
    // Load & store access.
    output                      ls_req_vld,
    input                       ls_req_rdy,
    output                      ls_req_read,
    output [ALEN-1:0]           ls_req_addr,
    output [MLEN-1:0]           ls_req_mask,
    output [XLEN-1:0]           ls_req_data,

    input                       ls_rsp_vld,
    output                      ls_rsp_rdy,
    input  [1:0]                ls_rsp_excp,
    input  [XLEN-1:0]           ls_rsp_data,

    // Control & status with SOC.
    output                      tmr_irq_clr,
    input                       irq_from_nmi,
    input                       irq_from_ext,
    input                       irq_from_sft,
    input                       irq_from_tmr,
    input  [63:0]               cnt_from_tmr,
    
    // To flush instruction channel.
    output                      fence_inst,     // FIXME: flush IFU for fence.i

    // To flush data channel.
    output                      fence_data,
    output [3:0]                fence_pred,
    output [3:0]                fence_succ,
    input                       fence_done
);
    
    localparam RF_AW            = 5;
    localparam RF_DP            = 32;

    // IFU to IDU.
    wire                        if2id_vld;
    wire                        if2id_rdy;
    
    wire [ILEN-1:0]             if2id_inst;
    wire [ALEN-1:0]             if2id_pc;
    wire [ALEN-1:0]             if2id_pc_nxt;
    wire                        if2id_br_tak;

    wire                        if2id_has_excp;
    wire                        if2id_acc_fault;
    wire                        if2id_mis_align;

    // IFU to BPU.
    wire                        if2bp_vld;
    wire [ALEN-1:0]             if2bp_pc;
    wire [31:0]                 if2bp_inst;
    wire                        if2bp_stall;

    wire                        bp2if_br_tak;
    wire                        bp2if_pc_vld;
    wire [31:0]                 bp2if_pc_nxt;
    
    // BPU to RF.
    wire [4:0]                  bp2rf_rd_idx;
    wire [XLEN-1:0]             bp2rf_rd_data;
    
    // IDU to EXU.
    wire                        id2ex_vld;
    wire                        id2ex_rdy;
    
    wire                        id2ex_alu_sgn;
    wire                        id2ex_alu_sft;
    wire                        id2ex_alu_stl;
    wire                        id2ex_alu_add;
    wire                        id2ex_alu_sub;
    wire                        id2ex_alu_lui;
    wire                        id2ex_alu_xor;
    wire                        id2ex_alu_or;
    wire                        id2ex_alu_and;
    wire                        id2ex_alu_slt;
    wire [XLEN-1:0]             id2ex_alu_opa;
    wire [XLEN-1:0]             id2ex_alu_opb;
    wire                        id2ex_opa_pc;
    
    wire                        id2ex_op_mul;
    wire                        id2ex_op_mix;
    wire                        id2ex_op_low;
    wire                        id2ex_op_div;
    wire                        id2ex_op_rem;

    wire                        id2ex_csr_rd;
    wire                        id2ex_csr_wr;
    wire                        id2ex_csr_rs;
    wire                        id2ex_csr_rc;
    wire                        id2ex_csr_imm;
    wire [11:0]                 id2ex_csr_idx;
    wire [XLEN-1:0]             id2ex_csr_val;

    wire                        id2ex_op_load;
    wire                        id2ex_op_loadu;
    wire                        id2ex_op_store;
    wire [MLEN-1:0]             id2ex_ls_mask;
    wire [XLEN-1:0]             id2ex_st_data;
    
    wire                        id2ex_op_bjp;
    wire                        id2ex_op_beq;
    wire                        id2ex_op_bne;
    wire                        id2ex_op_blt;
    wire                        id2ex_op_bge;
    wire                        id2ex_op_jal;
    wire                        id2ex_op_jalr;
    wire                        id2ex_op_branch;
    wire [ALEN-1:0]             id2ex_bjp_base;
    wire [ALEN-1:0]             id2ex_bjp_imm;
    wire [ILEN-1:0]             id2ex_inst;
    wire [ALEN-1:0]             id2ex_pc;
    wire [ALEN-1:0]             id2ex_pc_nxt;
    wire                        id2ex_br_tak;

    wire                        id2ex_op_mret;
    wire                        id2ex_op_wfi;
    
    wire                        id2ex_wb_act;
    wire [4:0]                  id2ex_wb_idx;
    
    wire                        id2ex_rs1_vld;
    wire                        id2ex_rs2_vld;
    wire [4:0]                  id2ex_rs1_idx;
    wire [4:0]                  id2ex_rs2_idx;

    wire                        id2ex_has_excp;
    wire                        id2ex_acc_fault;
    wire                        id2ex_mis_align;
    wire                        id2ex_ill_inst;
    wire                        id2ex_env_call;
    wire                        id2ex_env_break;
    
    // IDU to RF.
    wire [4:0]                  id2rf_ra_idx;
    wire [4:0]                  id2rf_rb_idx;
    wire [XLEN-1:0]             id2rf_ra_data;
    wire [XLEN-1:0]             id2rf_rb_data;

    // IDU forwarding.
    wire                        idu_fw_vld;
    wire [4:0]                  idu_fw_idx;
    wire [XLEN-1:0]             idu_fw_data;

    wire                        if2bp_fw_act;
    wire [4:0]                  if2bp_fw_idx;
    
    // EXU to CSR.
    wire                        ex2cs_rd_vld;
    wire                        ex2cs_wb_act;
    wire [11:0]                 ex2cs_rd_idx;
    wire [XLEN-1:0]             ex2cs_rd_data;
    wire                        ex2cs_csr_excp;

    // EXU to LSU.
    wire                        ex2ls_vld;
    wire                        ex2ls_rdy;
    
    wire                        ex2ls_op_load;
    wire                        ex2ls_op_loadu;
    wire                        ex2ls_op_store;
    wire [MLEN-1:0]             ex2ls_ls_mask;
    wire [ALEN-1:0]             ex2ls_ld_addr;
    wire [ALEN-1:0]             ex2ls_st_addr;
    wire [XLEN-1:0]             ex2ls_st_data;

    wire                        ex2ls_op_mret;
    wire                        ex2ls_op_wfi;
    
    wire                        exu_wb_act;
    wire                        exu_wb_vld;
    wire [4:0]                  exu_wb_idx;
    wire [XLEN-1:0]             exu_wb_data;

    wire                        ex2ls_csr_vld;
    wire [11:0]                 ex2ls_csr_idx;
    wire [XLEN-1:0]             ex2ls_csr_data;
    
    wire [ILEN-1:0]             ex2ls_inst;
    wire [ALEN-1:0]             ex2ls_pc;
    wire [ALEN-1:0]             ex2ls_pc_nxt;
    wire [4:0]                  ex2ls_rs2_idx;
    
    wire                        ex2ls_instret_vld;

    wire                        ex2ls_has_excp;
    wire                        ex2ls_acc_fault;
    wire                        ex2ls_mis_align;
    wire                        ex2ls_ill_inst;
    wire                        ex2ls_env_call;
    wire                        ex2ls_env_break;
    
    // IDU to IFU.
    wire                        id2if_bjp_vld;
    wire [ALEN-1:0]             id2if_bjp_addr;

    // EXU to IFU.
    wire                        ex2if_bjp_vld;
    wire [ALEN-1:0]             ex2if_bjp_addr;

    // EXU to IDU.
    wire                        ex2id_br_act;
    wire [4:0]                  ex2id_br_idx;

    // EXU forwarding.
    wire                        exu_fw_vld;
    wire [4:0]                  exu_fw_idx;
    wire [XLEN-1:0]             exu_fw_data;

    // Pipeline flush for branch & jump.
    wire                        id_br_flush;
    wire                        ex_br_flush;

    // LSU to commiter & forwarding.
    wire                        ls2cm_vld;
    wire                        ls2cm_rdy;

    wire                        lsu_wb_act;
    wire                        lsu_wb_vld;
    wire [4:0]                  lsu_wb_idx;
    wire [XLEN-1:0]             lsu_wb_data;

    wire                        lsu_csr_vld;
    wire [11:0]                 lsu_csr_idx;
    wire [XLEN-1:0]             lsu_csr_data;

    wire [ILEN-1:0]             ls2cm_inst;
    wire [ALEN-1:0]             ls2cm_pc;
    wire [ALEN-1:0]             ls2cm_pc_nxt;
    wire [ALEN-1:0]             ls2cm_ls_addr;

    wire                        ls2cm_if_acc_fault;
    wire                        ls2cm_if_mis_align;
    wire                        ls2cm_ld_acc_fault;
    wire                        ls2cm_ld_mis_align;
    wire                        ls2cm_st_acc_fault;
    wire                        ls2cm_st_mis_align;
    wire                        ls2cm_ill_inst;
    wire                        ls2cm_env_call;
    wire                        ls2cm_env_break;
    wire                        ls2cm_trap_exit;
    wire                        ls2cm_wfi;

    // CMT to RF.
    wire                        cmt_wb_vld;
    wire [4:0]                  cmt_wb_idx;
    wire [XLEN-1:0]             cmt_wb_data;

    // CSR status.
    wire                        cs2id_misa_ie;
    wire [XLEN-1:0]             cs2cm_mepc;
    wire [XLEN-1:0]             cs2cm_mtvec;
    wire                        cs2cm_mstatus_mie;
    wire                        cs2cm_mie_meie;
    wire                        cs2cm_mie_msie;
    wire                        cs2cm_mie_mtie;

    // CSR update.
    wire                        cm2cs_csr_vld;
    wire [11:0]                 cm2cs_csr_idx;
    wire [XLEN-1:0]             cm2cs_csr_data;
    wire                        cm2cs_instret;
    wire                        cm2cs_trap_trig;
    wire                        cm2cs_trap_exit;
    wire                        cm2cs_trap_type;
    wire [3:0]                  cm2cs_trap_code;
    wire [XLEN-1:0]             cm2cs_trap_mepc;
    wire [XLEN-1:0]             cm2cs_trap_info;

    // Pipeline flush for trap.
    wire                        trap_flush;
    wire [ALEN-1:0]             trap_pc;

    uv_ifu
    #(
        .ALEN                   ( ALEN                  ),
        .ILEN                   ( ILEN                  ),
        .XLEN                   ( XLEN                  )
    )
    u_ifu
    (
        .clk                    ( clk                   ),
        .rst_n                  ( rst_n                 ),
        
        // Memory reading.
        .if2mem_req_vld         ( if_req_vld            ),
        .if2mem_req_rdy         ( if_req_rdy            ),
        .if2mem_req_addr        ( if_req_addr           ),

        .if2mem_rsp_vld         ( if_rsp_vld            ),
        .if2mem_rsp_rdy         ( if_rsp_rdy            ),
        .if2mem_rsp_excp        ( if_rsp_excp           ),
        .if2mem_rsp_data        ( if_rsp_data           ),
        
        // Request to BPU.
        .if2bp_vld              ( if2bp_vld             ),
        .if2bp_pc               ( if2bp_pc              ),
        .if2bp_inst             ( if2bp_inst            ),
        .if2bp_stall            ( if2bp_stall           ),

        // Prediction from BPU.
        .bp2if_br_tak           ( bp2if_br_tak          ),
        .bp2if_pc_vld           ( bp2if_pc_vld          ),
        .bp2if_pc_nxt           ( bp2if_pc_nxt          ),

        // IDU handshake.
        .if2id_vld              ( if2id_vld             ),
        .if2id_rdy              ( if2id_rdy             ),
        
        // IDU status.
        .if2id_inst             ( if2id_inst            ),
        .if2id_pc               ( if2id_pc              ),
        .if2id_pc_nxt           ( if2id_pc_nxt          ),
        .if2id_br_tak           ( if2id_br_tak          ),

        .if2id_has_excp         ( if2id_has_excp        ),
        .if2id_acc_fault        ( if2id_acc_fault       ),
        .if2id_mis_align        ( if2id_mis_align       ),
        
        // Flush control from bjp misprediction.
        .id_br_flush            ( id_br_flush           ),
        .ex_br_flush            ( ex_br_flush           ),

        // Flush control from trap.
        .trap_flush             ( trap_flush            ),

        // Flush control by instruction.
        .fence_inst             ( fence_inst            ),

        // Redirection for bjp misprediction.
        .id2if_bjp_vld          ( id2if_bjp_vld         ),
        .id2if_bjp_addr         ( id2if_bjp_addr        ),

        .ex2if_bjp_vld          ( ex2if_bjp_vld         ),
        .ex2if_bjp_addr         ( ex2if_bjp_addr        ),

        // Redirection for trap.
        .cm2if_trap_vld         ( trap_flush            ),
        .cm2if_trap_addr        ( trap_pc               )
    );

    uv_bpu
    #(
        .ALEN                   ( ALEN                  ),
        .ILEN                   ( ILEN                  ),
        .XLEN                   ( XLEN                  )
    )
    u_bpu
    (
        .clk                    ( clk                   ),
        .rst_n                  ( rst_n                 ),
        
        // INFO from system.
        .rst_pc                 ( rst_vec               ),

        // INFO from IFU.
        .if2bp_vld              ( if2bp_vld             ),
        .if2bp_pc               ( if2bp_pc              ),
        .if2bp_inst             ( if2bp_inst            ),
        .if2bp_stall            ( if2bp_stall           ),

        // INFO from RF.
        .bp2rf_rd_idx           ( bp2rf_rd_idx          ),
        .bp2rf_rd_data          ( bp2rf_rd_data         ),

        // INFO from forwarding path.
        .if2bp_fw_act           ( if2bp_fw_act          ),
        .if2bp_fw_idx           ( if2bp_fw_idx          ),

        .id2bp_fw_act           ( id2ex_wb_act          ),
        .id2bp_fw_idx           ( id2ex_wb_idx          ),

        .ex2bp_fw_act           ( exu_wb_act            ),
        .ex2bp_fw_vld           ( exu_wb_vld            ),
        .ex2bp_fw_idx           ( exu_wb_idx            ),
        .ex2bp_fw_data          ( exu_wb_data           ),

        .ls2bp_fw_act           ( lsu_wb_act            ),
        .ls2bp_fw_vld           ( lsu_wb_vld            ),
        .ls2bp_fw_idx           ( lsu_wb_idx            ),
        .ls2bp_fw_data          ( lsu_wb_data           ),

        // Prediction result.
        .bp2if_br_tak           ( bp2if_br_tak          ),
        .bp2if_pc_vld           ( bp2if_pc_vld          ),
        .bp2if_pc_nxt           ( bp2if_pc_nxt          )
    );
    
    uv_idu
    #(
        .ALEN                   ( ALEN                  ),
        .ILEN                   ( ILEN                  ),
        .XLEN                   ( XLEN                  ),
        .MLEN                   ( MLEN                  )
    )
    u_idu
    (
        .clk                    ( clk                   ),
        .rst_n                  ( rst_n                 ),
        
        // IFU handshake.
        .if2id_vld              ( if2id_vld             ),
        .if2id_rdy              ( if2id_rdy             ),
        
        // IFU info.
        .if2id_inst             ( if2id_inst            ),
        .if2id_pc               ( if2id_pc              ),
        .if2id_pc_nxt           ( if2id_pc_nxt          ),
        .if2id_br_tak           ( if2id_br_tak          ),

        .if2id_has_excp         ( if2id_has_excp        ),
        .if2id_acc_fault        ( if2id_acc_fault       ),
        .if2id_mis_align        ( if2id_mis_align       ),
        
        // EXU handshake.
        .id2ex_vld              ( id2ex_vld             ),
        .id2ex_rdy              ( id2ex_rdy             ),
        
        // ALU info.
        .id2ex_alu_sgn          ( id2ex_alu_sgn         ),
        .id2ex_alu_sft          ( id2ex_alu_sft         ),
        .id2ex_alu_stl          ( id2ex_alu_stl         ),
        .id2ex_alu_add          ( id2ex_alu_add         ),
        .id2ex_alu_sub          ( id2ex_alu_sub         ),
        .id2ex_alu_lui          ( id2ex_alu_lui         ),
        .id2ex_alu_xor          ( id2ex_alu_xor         ),
        .id2ex_alu_or           ( id2ex_alu_or          ),
        .id2ex_alu_and          ( id2ex_alu_and         ),
        .id2ex_alu_slt          ( id2ex_alu_slt         ),
        .id2ex_alu_opa          ( id2ex_alu_opa         ),
        .id2ex_alu_opb          ( id2ex_alu_opb         ),
        .id2ex_opa_pc           ( id2ex_opa_pc          ),
        
        .id2ex_op_mul           ( id2ex_op_mul          ),
        .id2ex_op_mix           ( id2ex_op_mix          ),
        .id2ex_op_low           ( id2ex_op_low          ),
        .id2ex_op_div           ( id2ex_op_div          ),
        .id2ex_op_rem           ( id2ex_op_rem          ),

        // CSR info.
        .cs2id_misa_ie          ( cs2id_misa_ie         ),
        .id2ex_csr_rd           ( id2ex_csr_rd          ),
        .id2ex_csr_wr           ( id2ex_csr_wr          ),
        .id2ex_csr_rs           ( id2ex_csr_rs          ),
        .id2ex_csr_rc           ( id2ex_csr_rc          ),
        .id2ex_csr_imm          ( id2ex_csr_imm         ),
        .id2ex_csr_idx          ( id2ex_csr_idx         ),
        .id2ex_csr_val          ( id2ex_csr_val         ),

        // LSU info.
        .id2ex_op_load          ( id2ex_op_load         ),
        .id2ex_op_loadu         ( id2ex_op_loadu        ),
        .id2ex_op_store         ( id2ex_op_store        ),
        .id2ex_ls_mask          ( id2ex_ls_mask         ),
        .id2ex_st_data          ( id2ex_st_data         ),
        
        // BJP info.
        .id2ex_op_bjp           ( id2ex_op_bjp          ),
        .id2ex_op_beq           ( id2ex_op_beq          ),
        .id2ex_op_bne           ( id2ex_op_bne          ),
        .id2ex_op_blt           ( id2ex_op_blt          ),
        .id2ex_op_bge           ( id2ex_op_bge          ),
        .id2ex_op_jal           ( id2ex_op_jal          ),
        .id2ex_op_jalr          ( id2ex_op_jalr         ),
        .id2ex_op_branch        ( id2ex_op_branch       ),
        .id2ex_bjp_base         ( id2ex_bjp_base        ),
        .id2ex_bjp_imm          ( id2ex_bjp_imm         ),
        .id2ex_inst             ( id2ex_inst            ),
        .id2ex_pc               ( id2ex_pc              ),
        .id2ex_pc_nxt           ( id2ex_pc_nxt          ),
        .id2ex_br_tak           ( id2ex_br_tak          ),
        
        // Privileged info.
        .id2ex_op_mret          ( id2ex_op_mret         ),
        .id2ex_op_wfi           ( id2ex_op_wfi          ),

        // RF read.
        .id2rf_ra_idx           ( id2rf_ra_idx          ),
        .id2rf_rb_idx           ( id2rf_rb_idx          ),
        .id2rf_ra_data          ( id2rf_ra_data         ),
        .id2rf_rb_data          ( id2rf_rb_data         ),
        
        // WB info.
        .id2ex_wb_act           ( id2ex_wb_act          ),
        .id2ex_wb_idx           ( id2ex_wb_idx          ),

        // Excp info.
        .id2ex_has_excp         ( id2ex_has_excp        ),
        .id2ex_acc_fault        ( id2ex_acc_fault       ),
        .id2ex_mis_align        ( id2ex_mis_align       ),
        .id2ex_ill_inst         ( id2ex_ill_inst        ),
        .id2ex_env_call         ( id2ex_env_call        ),
        .id2ex_env_break        ( id2ex_env_break       ),
        
        // Forwarding info.
        .id2ex_rs1_vld          ( id2ex_rs1_vld         ),
        .id2ex_rs2_vld          ( id2ex_rs2_vld         ),
        .id2ex_rs1_idx          ( id2ex_rs1_idx         ),
        .id2ex_rs2_idx          ( id2ex_rs2_idx         ),
        
        .if2bp_fw_act           ( if2bp_fw_act          ),
        .if2bp_fw_idx           ( if2bp_fw_idx          ),
        
        .ex2id_fw_act           ( exu_wb_act            ),
        .ex2id_fw_vld           ( exu_wb_vld            ),
        .ex2id_fw_idx           ( exu_wb_idx            ),
        .ex2id_fw_data          ( exu_wb_data           ),

        .ex2id_br_act           ( ex2id_br_act          ),
        .ex2id_br_idx           ( ex2id_br_idx          ),

        .ls2id_fw_act           ( lsu_wb_act            ),
        .ls2id_fw_vld           ( lsu_wb_vld            ),
        .ls2id_fw_idx           ( lsu_wb_idx            ),
        .ls2id_fw_data          ( lsu_wb_data           ),
        
        // Flush control from bjp misprediction.
        .id_br_flush            ( id_br_flush           ),
        .ex_br_flush            ( ex_br_flush           ),

        .id2if_bjp_vld          ( id2if_bjp_vld         ),
        .id2if_bjp_addr         ( id2if_bjp_addr        ),
        
        // Flush control from trap.
        .trap_flush             ( trap_flush            ),
        
        // Fence info.
        .fence_inst             ( fence_inst            ),
        .fence_data             ( fence_data            ),
        .fence_pred             ( fence_pred            ),
        .fence_succ             ( fence_succ            ),
        .fence_done             ( fence_done            )
    );
    
    uv_exu
    #(
        .ALEN                   ( ALEN                  ),
        .ILEN                   ( ILEN                  ),
        .XLEN                   ( XLEN                  ),
        .MLEN                   ( MLEN                  )
    )
    u_exu
    (
        .clk                    ( clk                   ),
        .rst_n                  ( rst_n                 ),
        
        // IDU handshake.
        .id2ex_vld              ( id2ex_vld             ),
        .id2ex_rdy              ( id2ex_rdy             ),
        
        // IDU info.
        .id2ex_alu_sgn          ( id2ex_alu_sgn         ),
        .id2ex_alu_sft          ( id2ex_alu_sft         ),
        .id2ex_alu_stl          ( id2ex_alu_stl         ),
        .id2ex_alu_add          ( id2ex_alu_add         ),
        .id2ex_alu_sub          ( id2ex_alu_sub         ),
        .id2ex_alu_lui          ( id2ex_alu_lui         ),
        .id2ex_alu_xor          ( id2ex_alu_xor         ),
        .id2ex_alu_or           ( id2ex_alu_or          ),
        .id2ex_alu_and          ( id2ex_alu_and         ),
        .id2ex_alu_slt          ( id2ex_alu_slt         ),
        .id2ex_alu_opa          ( id2ex_alu_opa         ),
        .id2ex_alu_opb          ( id2ex_alu_opb         ),
        .id2ex_opa_pc           ( id2ex_opa_pc          ),

        .id2ex_op_mul           ( id2ex_op_mul          ),
        .id2ex_op_mix           ( id2ex_op_mix          ),
        .id2ex_op_low           ( id2ex_op_low          ),
        .id2ex_op_div           ( id2ex_op_div          ),
        .id2ex_op_rem           ( id2ex_op_rem          ),

        .id2ex_csr_rd           ( id2ex_csr_rd          ),
        .id2ex_csr_wr           ( id2ex_csr_wr          ),
        .id2ex_csr_rs           ( id2ex_csr_rs          ),
        .id2ex_csr_rc           ( id2ex_csr_rc          ),
        .id2ex_csr_imm          ( id2ex_csr_imm         ),
        .id2ex_csr_idx          ( id2ex_csr_idx         ),
        .id2ex_csr_val          ( id2ex_csr_val         ),
        
        .id2ex_op_load          ( id2ex_op_load         ),
        .id2ex_op_loadu         ( id2ex_op_loadu        ),
        .id2ex_op_store         ( id2ex_op_store        ),
        .id2ex_ls_mask          ( id2ex_ls_mask         ),
        .id2ex_st_data          ( id2ex_st_data         ),
        
        .id2ex_op_bjp           ( id2ex_op_bjp          ),
        .id2ex_op_beq           ( id2ex_op_beq          ),
        .id2ex_op_bne           ( id2ex_op_bne          ),
        .id2ex_op_blt           ( id2ex_op_blt          ),
        .id2ex_op_bge           ( id2ex_op_bge          ),
        .id2ex_op_jal           ( id2ex_op_jal          ),
        .id2ex_op_jalr          ( id2ex_op_jalr         ),
        .id2ex_op_branch        ( id2ex_op_branch       ),
        .id2ex_bjp_base         ( id2ex_bjp_base        ),
        .id2ex_bjp_imm          ( id2ex_bjp_imm         ),
        .id2ex_inst             ( id2ex_inst            ),
        .id2ex_pc               ( id2ex_pc              ),
        .id2ex_pc_nxt           ( id2ex_pc_nxt          ),
        .id2ex_br_tak           ( id2ex_br_tak          ),

        .id2ex_op_mret          ( id2ex_op_mret         ),
        .id2ex_op_wfi           ( id2ex_op_wfi          ),

        .id2ex_wb_act           ( id2ex_wb_act          ),
        .id2ex_wb_idx           ( id2ex_wb_idx          ),
        
        .id2ex_has_excp         ( id2ex_has_excp        ),
        .id2ex_acc_fault        ( id2ex_acc_fault       ),
        .id2ex_mis_align        ( id2ex_mis_align       ),
        .id2ex_ill_inst         ( id2ex_ill_inst        ),
        .id2ex_env_call         ( id2ex_env_call        ),
        .id2ex_env_break        ( id2ex_env_break       ),

        // CSR reading.
        .ex2cs_rd_vld           ( ex2cs_rd_vld          ),
        .ex2cs_wb_act           ( ex2cs_wb_act          ),
        .ex2cs_rd_idx           ( ex2cs_rd_idx          ),
        .ex2cs_rd_data          ( ex2cs_rd_data         ),
        .ex2cs_csr_excp         ( ex2cs_csr_excp        ),
        
        // LSU handshake.
        .ex2ls_vld              ( ex2ls_vld             ),
        .ex2ls_rdy              ( ex2ls_rdy             ),
        
        // LSU info.
        .ex2ls_op_load          ( ex2ls_op_load         ),
        .ex2ls_op_loadu         ( ex2ls_op_loadu        ),
        .ex2ls_op_store         ( ex2ls_op_store        ),
        .ex2ls_ls_mask          ( ex2ls_ls_mask         ),
        .ex2ls_ld_addr          ( ex2ls_ld_addr         ),
        .ex2ls_st_addr          ( ex2ls_st_addr         ),
        .ex2ls_st_data          ( ex2ls_st_data         ),
        
        // Privileged info.
        .ex2ls_op_mret          ( ex2ls_op_mret         ),
        .ex2ls_op_wfi           ( ex2ls_op_wfi          ),

        // WB info.
        .ex2ls_wb_act           ( exu_wb_act            ),
        .ex2ls_wb_vld           ( exu_wb_vld            ),
        .ex2ls_wb_idx           ( exu_wb_idx            ),
        .ex2ls_wb_data          ( exu_wb_data           ),

        // CSR writing.
        .ex2ls_csr_vld          ( ex2ls_csr_vld         ),
        .ex2ls_csr_idx          ( ex2ls_csr_idx         ),
        .ex2ls_csr_data         ( ex2ls_csr_data        ),

        // Fetch info.
        .ex2ls_inst             ( ex2ls_inst            ),
        .ex2ls_pc               ( ex2ls_pc              ),
        .ex2ls_pc_nxt           ( ex2ls_pc_nxt          ),

        // Excp info.
        .ex2ls_has_excp         ( ex2ls_has_excp        ),
        .ex2ls_acc_fault        ( ex2ls_acc_fault       ),
        .ex2ls_mis_align        ( ex2ls_mis_align       ),
        .ex2ls_ill_inst         ( ex2ls_ill_inst        ),
        .ex2ls_env_call         ( ex2ls_env_call        ),
        .ex2ls_env_break        ( ex2ls_env_break       ),

        // Flush control from bjp misprediction.
        .ex_br_flush            ( ex_br_flush           ),

        // Flush control from trap.
        .trap_flush             ( trap_flush            ),
        
        // Branch info to IFU.
        .ex2if_bjp_vld          ( ex2if_bjp_vld         ),
        .ex2if_bjp_addr         ( ex2if_bjp_addr        ),
        
        // Branch back-pressure to IDU.
        .ex2id_br_act           ( ex2id_br_act          ),
        .ex2id_br_idx           ( ex2id_br_idx          ),

        // Forwarding info from IDU & LSU.
        .id2ex_rs1_vld          ( id2ex_rs1_vld         ),
        .id2ex_rs2_vld          ( id2ex_rs2_vld         ),
        .id2ex_rs1_idx          ( id2ex_rs1_idx         ),
        .id2ex_rs2_idx          ( id2ex_rs2_idx         ),
        
        .ls2ex_fw_vld           ( lsu_wb_vld            ),
        .ls2ex_fw_idx           ( lsu_wb_idx            ),
        .ls2ex_fw_data          ( lsu_wb_data           ),

        .ls2ex_csr_vld          ( lsu_csr_vld           ),
        .ls2ex_csr_idx          ( lsu_csr_idx           ),
        .ls2ex_csr_data         ( lsu_csr_data          ),
        
        // Forwarding info to LSU.
        .ex2ls_rs2_idx          ( ex2ls_rs2_idx         )
    );
    
    uv_lsu
    #(
        .ALEN                   ( ALEN                  ),
        .XLEN                   ( XLEN                  ),
        .MLEN                   ( MLEN                  )
    )
    u_lsu
    (
        .clk                    ( clk                   ),
        .rst_n                  ( rst_n                 ),
        
        // EXU handshake.
        .ex2ls_vld              ( ex2ls_vld             ),
        .ex2ls_rdy              ( ex2ls_rdy             ),
        
        // EXU info.
        .ex2ls_op_load          ( ex2ls_op_load         ),
        .ex2ls_op_loadu         ( ex2ls_op_loadu        ),
        .ex2ls_op_store         ( ex2ls_op_store        ),
        .ex2ls_ls_mask          ( ex2ls_ls_mask         ),
        .ex2ls_ld_addr          ( ex2ls_ld_addr         ),
        .ex2ls_st_addr          ( ex2ls_st_addr         ),
        .ex2ls_st_data          ( ex2ls_st_data         ),
        
        .ex2ls_op_mret          ( ex2ls_op_mret         ),
        .ex2ls_op_wfi           ( ex2ls_op_wfi          ),

        .ex2ls_wb_act           ( exu_wb_act            ),
        .ex2ls_wb_vld           ( exu_wb_vld            ),
        .ex2ls_wb_idx           ( exu_wb_idx            ),
        .ex2ls_wb_data          ( exu_wb_data           ),

        .ex2ls_csr_vld          ( ex2ls_csr_vld         ),
        .ex2ls_csr_idx          ( ex2ls_csr_idx         ),
        .ex2ls_csr_data         ( ex2ls_csr_data        ),

        .ex2ls_inst             ( ex2ls_inst            ),
        .ex2ls_pc               ( ex2ls_pc              ),
        .ex2ls_pc_nxt           ( ex2ls_pc_nxt          ),

        .ex2ls_has_excp         ( ex2ls_has_excp        ),
        .ex2ls_acc_fault        ( ex2ls_acc_fault       ),
        .ex2ls_mis_align        ( ex2ls_mis_align       ),
        .ex2ls_ill_inst         ( ex2ls_ill_inst        ),
        .ex2ls_env_call         ( ex2ls_env_call        ),
        .ex2ls_env_break        ( ex2ls_env_break       ),
        
        // MEM info.
        .ls2mem_req_vld         ( ls_req_vld            ),
        .ls2mem_req_rdy         ( ls_req_rdy            ),
        .ls2mem_req_read        ( ls_req_read           ),
        .ls2mem_req_addr        ( ls_req_addr           ),
        .ls2mem_req_mask        ( ls_req_mask           ),
        .ls2mem_req_data        ( ls_req_data           ),

        .ls2mem_rsp_vld         ( ls_rsp_vld            ),
        .ls2mem_rsp_rdy         ( ls_rsp_rdy            ),
        .ls2mem_rsp_excp        ( ls_rsp_excp           ),
        .ls2mem_rsp_data        ( ls_rsp_data           ),
        
        // CMT handshake.
        .ls2cm_vld              ( ls2cm_vld             ),
        .ls2cm_rdy              ( ls2cm_rdy             ), 

        // Fetch info to CMT.
        .ls2cm_inst             ( ls2cm_inst            ),
        .ls2cm_pc               ( ls2cm_pc              ),
        .ls2cm_pc_nxt           ( ls2cm_pc_nxt          ),

        // LS info to CMT.
        .ls2cm_ls_addr          ( ls2cm_ls_addr         ),

        // WB & FW info to RF & EXU, respectively.
        .ls2cm_wb_act           ( lsu_wb_act            ),
        .ls2cm_wb_vld           ( lsu_wb_vld            ),
        .ls2cm_wb_idx           ( lsu_wb_idx            ),
        .ls2cm_wb_data          ( lsu_wb_data           ),

        // CSR writing.
        .ls2cm_csr_vld          ( lsu_csr_vld           ),
        .ls2cm_csr_idx          ( lsu_csr_idx           ),
        .ls2cm_csr_data         ( lsu_csr_data          ),
        
        // Excp info to CMT.
        .ls2cm_if_acc_fault     ( ls2cm_if_acc_fault    ),
        .ls2cm_if_mis_align     ( ls2cm_if_mis_align    ),
        .ls2cm_ld_acc_fault     ( ls2cm_ld_acc_fault    ),
        .ls2cm_ld_mis_align     ( ls2cm_ld_mis_align    ),
        .ls2cm_st_acc_fault     ( ls2cm_st_acc_fault    ),
        .ls2cm_st_mis_align     ( ls2cm_st_mis_align    ),
        .ls2cm_ill_inst         ( ls2cm_ill_inst        ),
        .ls2cm_env_call         ( ls2cm_env_call        ),
        .ls2cm_env_break        ( ls2cm_env_break       ),
        .ls2cm_trap_exit        ( ls2cm_trap_exit       ),
        .ls2cm_wfi              ( ls2cm_wfi             ),

        // Flush control from trap.
        .trap_flush             ( trap_flush            ),
        
        // FW info from EXU.
        .ex2ls_rs2_idx          ( ex2ls_rs2_idx         )
    );

    uv_cmt
    #(
        .ALEN                   ( ALEN                  ),
        .ILEN                   ( ILEN                  ),
        .XLEN                   ( XLEN                  ),
        .MLEN                   ( MLEN                  )
    )
    u_cmt
    (
        .clk                    ( clk                   ),
        .rst_n                  ( rst_n                 ),
        
        // LSU handshake.
        .ls2cm_vld              ( ls2cm_vld             ),
        .ls2cm_rdy              ( ls2cm_rdy             ),

        // RF write back info.
        .ls2cm_wb_act           ( lsu_wb_act            ),
        .ls2cm_wb_vld           ( lsu_wb_vld            ),
        .ls2cm_wb_idx           ( lsu_wb_idx            ),
        .ls2cm_wb_data          ( lsu_wb_data           ),

        // CSR write back info.
        .ls2cm_csr_vld          ( lsu_csr_vld           ),
        .ls2cm_csr_idx          ( lsu_csr_idx           ),
        .ls2cm_csr_data         ( lsu_csr_data          ),

        // Fetch info.
        .ls2cm_inst             ( ls2cm_inst            ),
        .ls2cm_pc               ( ls2cm_pc              ),
        .ls2cm_pc_nxt           ( ls2cm_pc_nxt          ),

        // LS info.
        .ls2cm_ls_addr          ( ls2cm_ls_addr         ),

        // CSR status.
        .cs2cm_mepc             ( cs2cm_mepc            ),
        .cs2cm_mtvec            ( cs2cm_mtvec           ),
        .cs2cm_mstatus_mie      ( cs2cm_mstatus_mie     ),
        .cs2cm_mie_meie         ( cs2cm_mie_meie        ),
        .cs2cm_mie_msie         ( cs2cm_mie_msie        ),
        .cs2cm_mie_mtie         ( cs2cm_mie_mtie        ),

        // Exception info.
        .ls2cm_if_acc_fault     ( ls2cm_if_acc_fault    ),
        .ls2cm_if_mis_align     ( ls2cm_if_mis_align    ),
        .ls2cm_ld_acc_fault     ( ls2cm_ld_acc_fault    ),
        .ls2cm_ld_mis_align     ( ls2cm_ld_mis_align    ),
        .ls2cm_st_acc_fault     ( ls2cm_st_acc_fault    ),
        .ls2cm_st_mis_align     ( ls2cm_st_mis_align    ),
        .ls2cm_ill_inst         ( ls2cm_ill_inst        ),
        .ls2cm_env_call         ( ls2cm_env_call        ),
        .ls2cm_env_break        ( ls2cm_env_break       ),
        .ls2cm_trap_exit        ( ls2cm_trap_exit       ),
        .ls2cm_wfi              ( ls2cm_wfi             ),

        // Interrupt request.
        .irq_from_ext           ( irq_from_ext          ),
        .irq_from_sft           ( irq_from_sft          ),
        .irq_from_tmr           ( irq_from_tmr          ),
        .irq_from_nmi           ( irq_from_nmi          ),

        // Interrutp clearing.
        .tmr_irq_clr            ( tmr_irq_clr           ),

        // Regfile writing.
        .cm2rf_wb_vld           ( cmt_wb_vld            ),
        .cm2rf_wb_idx           ( cmt_wb_idx            ),
        .cm2rf_wb_data          ( cmt_wb_data           ),

        // CSR updating.
        .cm2cs_csr_vld          ( cm2cs_csr_vld         ),
        .cm2cs_csr_idx          ( cm2cs_csr_idx         ),
        .cm2cs_csr_data         ( cm2cs_csr_data        ),
        .cm2cs_instret          ( cm2cs_instret         ),
        .cm2cs_trap_trig        ( cm2cs_trap_trig       ),
        .cm2cs_trap_exit        ( cm2cs_trap_exit       ),
        .cm2cs_trap_type        ( cm2cs_trap_type       ),
        .cm2cs_trap_code        ( cm2cs_trap_code       ),
        .cm2cs_trap_mepc        ( cm2cs_trap_mepc       ),
        .cm2cs_trap_info        ( cm2cs_trap_info       ),

        // Pipeline flush.
        .trap_flush             ( trap_flush            ),
        .trap_pc                ( trap_pc               )
    );
    
    uv_regfile
    #(
        .RF_AW                  ( RF_AW                 ),
        .RF_DP                  ( RF_DP                 ),
        .RF_DW                  ( XLEN                  )
    )
    u_rf
    (       
        .clk                    ( clk                   ),
        .rst_n                  ( rst_n                 ),
        
        .wr_vld                 ( cmt_wb_vld            ),
        .wr_idx                 ( cmt_wb_idx            ),
        .wr_data                ( cmt_wb_data           ),

        .ra_idx                 ( id2rf_ra_idx          ),
        .rb_idx                 ( id2rf_rb_idx          ),
        .rc_idx                 ( bp2rf_rd_idx          ),
        .ra_data                ( id2rf_ra_data         ),
        .rb_data                ( id2rf_rb_data         ),
        .rc_data                ( bp2rf_rd_data         )
    );

    uv_csr
    #(
        .XLEN                   ( XLEN                  ),
        .ARCH_ID                ( ARCH_ID               ),
        .IMPL_ID                ( IMPL_ID               ),
        .HART_ID                ( HART_ID               ),
        .VENDOR_ID              ( VENDOR_ID             )
    )
    u_csr
    (
        .clk                    ( clk                   ),
        .rst_n                  ( rst_n                 ),
        
        .csr_rd_vld             ( ex2cs_rd_vld          ),
        .csr_wb_act             ( ex2cs_wb_act          ),
        .csr_rd_idx             ( ex2cs_rd_idx          ),
        .csr_rd_data            ( ex2cs_rd_data         ),

        .csr_wr_vld             ( cm2cs_csr_vld         ),
        .csr_wr_idx             ( cm2cs_csr_idx         ),
        .csr_wr_data            ( cm2cs_csr_data        ),

        .dbg_mode               ( 1'b0                  ),  // FIXME: support debug mode.
        .pri_level              ( 2'b11                 ),
        .map_mtime              ( cnt_from_tmr          ),

        .trap_trig              ( cm2cs_trap_trig       ),
        .trap_exit              ( cm2cs_trap_exit       ),
        .trap_type              ( cm2cs_trap_type       ),
        .trap_code              ( cm2cs_trap_code       ),
        .trap_mepc              ( cm2cs_trap_mepc       ),
        .trap_info              ( cm2cs_trap_info       ),

        .intr_ext               ( irq_from_ext          ),
        .intr_sft               ( irq_from_sft          ),
        .intr_tmr               ( irq_from_tmr          ),

        .instret_inc            ( cm2cs_instret         ),
        
        .out_misa_ie            ( cs2id_misa_ie         ),
        .out_mepc               ( cs2cm_mepc            ),
        .out_mtvec              ( cs2cm_mtvec           ),
        .out_mstatus_mie        ( cs2cm_mstatus_mie     ),
        .out_mie_meie           ( cs2cm_mie_meie        ),
        .out_mie_msie           ( cs2cm_mie_msie        ),
        .out_mie_mtie           ( cs2cm_mie_mtie        ),

        .csr_excp               ( ex2cs_csr_excp        )
    );

endmodule

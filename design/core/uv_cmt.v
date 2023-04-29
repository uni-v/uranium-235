//************************************************************
// See LICENSE for license details.
//
// Module: uv_cmt
//
// Designer: Owen
//
// Description:
//      Committer for write back & exception handling.
//************************************************************

`timescale 1ns / 1ps

module uv_cmt
#(
    parameter ALEN = 32,
    parameter ILEN = 32,
    parameter XLEN = 32,
    parameter MLEN = XLEN / 8
)
(
    input                   clk,
    input                   rst_n,
    
    // LSU handshake.
    input                   ls2cm_vld,
    output                  ls2cm_rdy,

    // RF write back info.
    input                   ls2cm_wb_act,
    input                   ls2cm_wb_vld,
    input  [4:0]            ls2cm_wb_idx,
    input  [XLEN-1:0]       ls2cm_wb_data,

    // CSR write back info.
    input                   ls2cm_csr_vld,
    input  [11:0]           ls2cm_csr_idx,
    input  [XLEN-1:0]       ls2cm_csr_data,

    // Fetch info.
    input  [ILEN-1:0]       ls2cm_inst,
    input  [ALEN-1:0]       ls2cm_pc,
    input  [ALEN-1:0]       ls2cm_pc_nxt,

    // LS info.
    input  [ALEN-1:0]       ls2cm_ls_addr,

    // CSR status.
    input  [XLEN-1:0]       cs2cm_mepc,
    input  [XLEN-1:0]       cs2cm_mtvec,
    input                   cs2cm_mstatus_mie,
    input                   cs2cm_mie_meie,
    input                   cs2cm_mie_msie,
    input                   cs2cm_mie_mtie,

    // Exception info.
    input                   ls2cm_if_acc_fault,
    input                   ls2cm_if_mis_align,
    input                   ls2cm_ld_acc_fault,
    input                   ls2cm_ld_mis_align,
    input                   ls2cm_st_acc_fault,
    input                   ls2cm_st_mis_align,
    input                   ls2cm_ill_inst,
    input                   ls2cm_env_call,
    input                   ls2cm_env_break,
    input                   ls2cm_trap_exit,
    input                   ls2cm_wfi,

    // Interrupt request.
    input                   irq_from_ext,
    input                   irq_from_sft,
    input                   irq_from_tmr,
    input                   irq_from_nmi,

    // Interrutp clearing.
    output                  tmr_irq_clr,

    // Regfile writing.
    output                  cm2rf_wb_vld,
    output [4:0]            cm2rf_wb_idx,
    output [XLEN-1:0]       cm2rf_wb_data,

    // CSR updating.
    output                  cm2cs_csr_vld,
    output [11:0]           cm2cs_csr_idx,
    output [XLEN-1:0]       cm2cs_csr_data,
    output                  cm2cs_instret,
    output                  cm2cs_trap_trig,
    output                  cm2cs_trap_exit,
    output                  cm2cs_trap_type,
    output [3:0]            cm2cs_trap_code,
    output [XLEN-1:0]       cm2cs_trap_mepc,
    output [XLEN-1:0]       cm2cs_trap_info,

    // Pipeline flush.
    output                  trap_flush,
    output [ALEN-1:0]       trap_pc
);

    localparam UDLY         = 1;
    genvar i;

    wire                    cmt_with_irq_ext;
    wire                    cmt_with_irq_sft;
    wire                    cmt_with_irq_tmr;
    wire                    cmt_with_irq_nmi;
    wire                    cmt_with_intr;

    wire                    cmt_with_if_excp;
    wire                    cmt_with_ls_excp;
    wire                    cmt_with_excp;

    wire                    cmt_with_trap;
    wire                    cmt_with_eret;

    wire [3:0]              trap_code_irq;
    wire [3:0]              trap_code_excp;

    wire [1:0]              mtvec_mode;
    wire [XLEN-1:0]         mtvec_base;
    wire [XLEN-1:0]         mtvec_vpc;
    wire [XLEN-1:0]         mtvec_pc;

    reg                     trap_flush_r;
    reg  [ALEN-1:0]         trap_pc_r;

    reg                     trap_trig_r;
    reg                     trap_exit_r;
    reg                     trap_type_r;
    reg  [3:0]              trap_code_r;
    reg  [XLEN-1:0]         trap_mepc_r;
    reg  [XLEN-1:0]         trap_info_r;

    // Summary interrupts & exceptions.
    assign cmt_with_irq_ext = ls2cm_vld & cs2cm_mstatus_mie & cs2cm_mie_meie & irq_from_ext;
    assign cmt_with_irq_sft = ls2cm_vld & cs2cm_mstatus_mie & cs2cm_mie_msie & irq_from_sft;
    assign cmt_with_irq_tmr = ls2cm_vld & cs2cm_mstatus_mie & cs2cm_mie_mtie & irq_from_tmr;
    assign cmt_with_irq_nmi = ls2cm_vld & irq_from_nmi;
    assign cmt_with_irq     = cmt_with_irq_ext
                            | cmt_with_irq_sft
                            | cmt_with_irq_tmr
                            | cmt_with_irq_nmi;

    assign cmt_with_if_excp = ls2cm_vld & (ls2cm_if_acc_fault | ls2cm_if_mis_align);
    assign cmt_with_ls_excp = ls2cm_vld & (ls2cm_ld_acc_fault | ls2cm_ld_mis_align |    
                                           ls2cm_st_acc_fault | ls2cm_st_mis_align);
    assign cmt_with_excp    = ls2cm_vld & (cmt_with_if_excp   | cmt_with_ls_excp |
                                           ls2cm_env_call     | ls2cm_env_break  |
                                           ls2cm_ill_inst);
    
    assign cmt_with_trap    = cmt_with_irq | cmt_with_excp;
    assign cmt_with_eret    = ls2cm_vld & ls2cm_trap_exit;

    assign tmr_irq_clr      = (~cmt_with_irq_nmi) & (~cmt_with_irq_ext)
                            & (~cmt_with_irq_sft) & cmt_with_irq_tmr;

    // Generate trap code according to priority.
    assign trap_code_irq    = cmt_with_irq_nmi   ? 4'd15
                            : cmt_with_irq_ext   ? 4'd11
                            : cmt_with_irq_sft   ? 4'd3
                            : cmt_with_irq_tmr   ? 4'd7
                            : 4'b0;
    assign trap_code_excp   = (~ls2cm_vld)       ? 4'd0
                            : ls2cm_env_break    ? 4'd3
                            : ls2cm_if_acc_fault ? 4'd1
                            : ls2cm_ill_inst     ? 4'd2
                            : ls2cm_if_mis_align ? 4'd0
                            : ls2cm_env_call     ? 4'd11
                            : ls2cm_st_mis_align ? 4'd6
                            : ls2cm_ld_mis_align ? 4'd4
                            : ls2cm_st_acc_fault ? 4'd7
                            : ls2cm_ld_acc_fault ? 4'd5
                            : 4'd0;

    // Calculate trapped program counter.
    assign mtvec_mode       = cs2cm_mtvec[1:0];
    assign mtvec_base       = {cs2cm_mtvec[XLEN-1:2], 2'b00};
    assign mtvec_vpc        = mtvec_base + {trap_code_irq, 2'b00};
    assign mtvec_pc         = (mtvec_mode[0] & cmt_with_irq) ? mtvec_vpc : mtvec_base;

    // Flush pipeline.
    // assign trap_flush       = cmt_with_trap | cmt_with_eret;
    // assign trap_pc          = cmt_with_trap ? mtvec_pc[ALEN-1:0]
    //                         : cmt_with_eret ? cs2cm_mepc[ALEN-1:0]
    //                         : {ALEN{1'b0}};

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            trap_flush_r    <= 1'b0;
            trap_pc_r       <= {ALEN{1'b0}};
        end
        else begin
            trap_flush_r    <= #UDLY cmt_with_trap | cmt_with_eret;
            trap_pc_r       <= #UDLY cmt_with_trap ? mtvec_pc[ALEN-1:0]
                                   : cmt_with_eret ? cs2cm_mepc[ALEN-1:0]
                                   : {ALEN{1'b0}};
        end
    end

    assign trap_flush       = trap_flush_r;
    assign trap_pc          = trap_pc_r;

    // Always ready to commit.
    assign ls2cm_rdy        = 1'b1;

    // Write back to register file.
    assign cm2rf_wb_vld     = cmt_with_excp ? 1'b0 : ls2cm_wb_vld;
    assign cm2rf_wb_idx     = cmt_with_excp ? 5'b0 : ls2cm_wb_idx;
    assign cm2rf_wb_data    = cmt_with_excp ? {XLEN{1'b0}} : ls2cm_wb_data;

    // Update CSR.
    assign cm2cs_csr_vld    = cmt_with_excp ? 1'b0  : ls2cm_csr_vld;
    assign cm2cs_csr_idx    = cmt_with_excp ? 12'b0 : ls2cm_csr_idx;
    assign cm2cs_csr_data   = cmt_with_excp ? {XLEN{1'b0}} : ls2cm_csr_data;
    assign cm2cs_instret    = cmt_with_excp ? 1'b0  : ls2cm_vld;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            trap_trig_r     <= 1'b0;
            trap_exit_r     <= 1'b0;
            trap_type_r     <= 1'b0;
            trap_code_r     <= 3'b0;
            trap_mepc_r     <= {XLEN{1'b0}};
            trap_info_r     <= {XLEN{1'b0}};
        end
        else begin
            trap_trig_r     <= #UDLY cmt_with_trap;
            trap_exit_r     <= #UDLY cmt_with_eret;
            trap_type_r     <= #UDLY cmt_with_irq;
            trap_code_r     <= #UDLY cmt_with_irq ? trap_code_irq : trap_code_excp;
            trap_mepc_r     <= #UDLY cmt_with_irq ? ls2cm_pc_nxt : ls2cm_pc;
            trap_info_r     <= #UDLY ls2cm_ill_inst   ? ls2cm_inst
                                   : cmt_with_if_excp ? ls2cm_pc
                                   : cmt_with_ls_excp ? ls2cm_ls_addr
                                   : {XLEN{1'b0}};
        end
    end

    assign cm2cs_trap_trig  = trap_trig_r;
    assign cm2cs_trap_exit  = trap_exit_r;
    assign cm2cs_trap_type  = trap_type_r;
    assign cm2cs_trap_code  = trap_code_r;
    assign cm2cs_trap_mepc  = trap_mepc_r;
    assign cm2cs_trap_info  = trap_info_r;

endmodule

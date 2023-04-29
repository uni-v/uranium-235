//************************************************************
// See LICENSE for license details.
//
// Module: uv_lsu
//
// Designer: Owen
//
// Description:
//      Load-Store Unit.
//************************************************************

`timescale 1ns / 1ps

module uv_lsu
#(
    parameter ALEN = 32,
    parameter ILEN = 32,
    parameter XLEN = 32,
    parameter MLEN = XLEN / 8
)
(
    input                   clk,
    input                   rst_n,
    
    // EXU handshake.
    input                   ex2ls_vld,
    output                  ex2ls_rdy,
    
    // EXU info.
    input                   ex2ls_op_load,
    input                   ex2ls_op_loadu,
    input                   ex2ls_op_store,
    input  [MLEN-1:0]       ex2ls_ls_mask,
    input  [ALEN-1:0]       ex2ls_ld_addr,
    input  [ALEN-1:0]       ex2ls_st_addr,
    input  [XLEN-1:0]       ex2ls_st_data,

    input                   ex2ls_op_mret,
    input                   ex2ls_op_wfi,
    
    input                   ex2ls_wb_act,
    input                   ex2ls_wb_vld,
    input  [4:0]            ex2ls_wb_idx,
    input  [XLEN-1:0]       ex2ls_wb_data,

    input                   ex2ls_csr_vld,
    input  [11:0]           ex2ls_csr_idx,
    input  [XLEN-1:0]       ex2ls_csr_data,

    input  [ILEN-1:0]       ex2ls_inst,
    input  [ALEN-1:0]       ex2ls_pc,
    input  [ALEN-1:0]       ex2ls_pc_nxt,

    // Exceptions.
    input                   ex2ls_has_excp,
    input                   ex2ls_acc_fault,
    input                   ex2ls_mis_align,
    input                   ex2ls_ill_inst,
    input                   ex2ls_env_call,
    input                   ex2ls_env_break,
    
    // MEM access.
    output                  ls2mem_req_vld,
    input                   ls2mem_req_rdy,
    output                  ls2mem_req_read,
    output [ALEN-1:0]       ls2mem_req_addr,
    output [MLEN-1:0]       ls2mem_req_mask,
    output [XLEN-1:0]       ls2mem_req_data,

    input                   ls2mem_rsp_vld,
    output                  ls2mem_rsp_rdy,
    input  [1:0]            ls2mem_rsp_excp,
    input  [XLEN-1:0]       ls2mem_rsp_data,
    
    // CMT handshake.
    output                  ls2cm_vld,
    input                   ls2cm_rdy,      // Reserved!

    // Fetch info to CMT.
    output [ILEN-1:0]       ls2cm_inst,
    output [ALEN-1:0]       ls2cm_pc,
    output [ALEN-1:0]       ls2cm_pc_nxt,

    // LS info to CMT.
    output [ALEN-1:0]       ls2cm_ls_addr,

    // WB & FW info to CMT & EXU.
    output                  ls2cm_wb_act,
    output                  ls2cm_wb_vld,
    output [4:0]            ls2cm_wb_idx,
    output [XLEN-1:0]       ls2cm_wb_data,

    // CSR writing.
    output                  ls2cm_csr_vld,
    output [11:0]           ls2cm_csr_idx,
    output [XLEN-1:0]       ls2cm_csr_data,

    // Excp info to CMT.
    output                  ls2cm_if_acc_fault,
    output                  ls2cm_if_mis_align,
    output                  ls2cm_ld_acc_fault,
    output                  ls2cm_ld_mis_align,
    output                  ls2cm_st_acc_fault,
    output                  ls2cm_st_mis_align,
    output                  ls2cm_ill_inst,
    output                  ls2cm_env_call,
    output                  ls2cm_env_break,
    output                  ls2cm_trap_exit,
    output                  ls2cm_wfi,

    // Flush control from trap.
    input                   trap_flush,
    
    // FW info from EXU
    input  [4:0]            ex2ls_rs2_idx
);

    localparam UDLY         = 1;
    genvar i;

    // Pipeline flush.
    wire                    pipe_flush;

    // Handshake.
    wire                    pipe_nxt;
    wire                    ex2ls_fire;
    wire                    ex2ls_real;
    reg                     ex2ls_fire_p;
    reg                     ex2ls_init_p;

    // Input buffer.
    reg                     ex2ls_op_load_r;
    reg                     ex2ls_op_loadu_r;
    reg                     ex2ls_op_store_r;
    reg  [MLEN-1:0]         ex2ls_ls_mask_r;
    reg  [ALEN-1:0]         ex2ls_ld_addr_r;
    reg  [ALEN-1:0]         ex2ls_st_addr_r;
    reg  [XLEN-1:0]         ex2ls_st_data_r;
    reg                     ex2ls_op_mret_r;
    reg                     ex2ls_op_wfi_r;
    reg                     ex2ls_wb_act_r;
    reg                     ex2ls_wb_vld_r;
    reg  [4:0]              ex2ls_wb_idx_r;
    reg  [XLEN-1:0]         ex2ls_wb_data_r;
    reg                     ex2ls_csr_vld_r;
    reg  [11:0]             ex2ls_csr_idx_r;
    reg  [XLEN-1:0]         ex2ls_csr_data_r;
    reg  [ILEN-1:0]         ex2ls_inst_r;
    reg  [ALEN-1:0]         ex2ls_pc_r;
    reg  [ALEN-1:0]         ex2ls_pc_nxt_r;
    reg                     ex2ls_has_excp_r;
    reg                     ex2ls_acc_fault_r;
    reg                     ex2ls_mis_align_r;
    reg                     ex2ls_ill_inst_r;
    reg                     ex2ls_env_call_r;
    reg                     ex2ls_env_break_r;

    wire                    pipe_op_load;
    wire                    pipe_op_loadu;
    wire                    pipe_op_store;
    wire [MLEN-1:0]         pipe_ls_mask;
    wire [ALEN-1:0]         pipe_ld_addr;
    wire [ALEN-1:0]         pipe_st_addr;
    wire [XLEN-1:0]         pipe_st_data;
    wire                    pipe_op_mret;
    wire                    pipe_op_wfi;
    wire                    pipe_wb_act;
    wire                    pipe_wb_vld;
    wire [4:0]              pipe_wb_idx;
    wire [XLEN-1:0]         pipe_wb_data;
    wire                    pipe_csr_vld;
    wire [11:0]             pipe_csr_idx;
    wire [XLEN-1:0]         pipe_csr_data;
    wire [ILEN-1:0]         pipe_inst;
    wire [ALEN-1:0]         pipe_pc;
    wire [ALEN-1:0]         pipe_pc_nxt;
    wire                    pipe_has_excp;
    wire                    pipe_acc_fault;
    wire                    pipe_mis_align;
    wire                    pipe_ill_inst;
    wire                    pipe_env_call;
    wire                    pipe_env_break;
    
    // Memory access.
    wire                    mem_req_read;
    wire                    mem_req_fire;
    wire                    mem_rsp_fire;
    wire                    mem_ld_fire;
    wire                    mem_st_fire;
    wire                    mem_ld_sign;
    wire [XLEN-1:0]         msk_ld_data;
    wire [XLEN-1:0]         mem_wb_data;
    wire                    mem_ld_wait;
    wire                    mem_st_wait;
    
    // Forwarding at LSU ifself.
    wire                    st_rs2_frm_wb;
    
    // WB summary.
    wire                    wb_act;
    wire                    wb_vld;
    wire [4:0]              wb_idx;
    wire [XLEN-1:0]         wb_data;

    // LS delay & data buf.
    reg  [MLEN-1:0]         mem_ld_mask_p;
    reg  [XLEN-1:0]         mem_ld_data_r;
    reg                     mem_ld_usgn_p;
    reg                     mem_ld_req_r;
    reg                     mem_st_req_r;
    
    // Commit buf register.
    reg                     ls2cm_vld_r;
    reg                     inst_non_ls_r;
    reg                     trap_exit_r;
    reg                     wfi_r;

    // WB buf registers.
    reg                     wb_act_r;
    reg                     wb_vld_r;
    reg  [4:0]              wb_idx_r;
    reg  [XLEN-1:0]         wb_data_r;

    reg                     csr_vld_r;
    reg  [11:0]             csr_idx_r;
    reg  [XLEN-1:0]         csr_data_r;

    // Fetch buf registers.
    reg  [ILEN-1:0]         inst_r;
    reg  [ALEN-1:0]         pc_r;
    reg  [ALEN-1:0]         pc_nxt_r;

    // Load/store address.
    reg  [ALEN-1:0]         ls_addr_r;

    // Exception buf registers.
    reg                     if_acc_fault_r;
    reg                     if_mis_align_r;
    reg                     ill_inst_r;
    reg                     env_call_r;
    reg                     env_break_r;
    
    // Only one flush source for LSU.
    assign pipe_flush       = trap_flush;

    // Handshake: response to EXU.
    assign pipe_nxt         = ex2ls_vld & (~pipe_flush);
    //assign ex2ls_rdy      = ~(ls2mem_req_vld & (~ls2mem_req_rdy));
    assign ex2ls_rdy        = ~((ls2mem_req_vld & (~ls2mem_req_rdy)) | mem_ld_wait | mem_st_wait);
    assign ex2ls_fire       = ex2ls_vld & ex2ls_rdy;
    assign ex2ls_real       = ex2ls_fire_p | ex2ls_init_p;
    
    // Select pipeline sources.
    assign pipe_op_load     = ex2ls_real ? ex2ls_op_load     : ex2ls_op_load_r;
    assign pipe_op_loadu    = ex2ls_real ? ex2ls_op_loadu    : ex2ls_op_loadu_r;
    assign pipe_op_store    = ex2ls_real ? ex2ls_op_store    : ex2ls_op_store_r;
    assign pipe_ls_mask     = ex2ls_real ? ex2ls_ls_mask     : ex2ls_ls_mask_r;
    assign pipe_ld_addr     = ex2ls_real ? ex2ls_ld_addr     : ex2ls_ld_addr_r;
    assign pipe_st_addr     = ex2ls_real ? ex2ls_st_addr     : ex2ls_st_addr_r;
    assign pipe_st_data     = ex2ls_real ? ex2ls_st_data     : ex2ls_st_data_r;
    assign pipe_op_mret     = ex2ls_real ? ex2ls_op_mret     : ex2ls_op_mret_r;
    assign pipe_op_wfi      = ex2ls_real ? ex2ls_op_wfi      : ex2ls_op_wfi_r;
    assign pipe_wb_act      = ex2ls_real ? ex2ls_wb_act      : ex2ls_wb_act_r;
    assign pipe_wb_vld      = ex2ls_real ? ex2ls_wb_vld      : ex2ls_wb_vld_r;
    assign pipe_wb_idx      = ex2ls_real ? ex2ls_wb_idx      : ex2ls_wb_idx_r;
    assign pipe_wb_data     = ex2ls_real ? ex2ls_wb_data     : ex2ls_wb_data_r;
    assign pipe_csr_vld     = ex2ls_real ? ex2ls_csr_vld     : ex2ls_csr_vld_r;
    assign pipe_csr_idx     = ex2ls_real ? ex2ls_csr_idx     : ex2ls_csr_idx_r;
    assign pipe_csr_data    = ex2ls_real ? ex2ls_csr_data    : ex2ls_csr_data_r;
    assign pipe_inst        = ex2ls_real ? ex2ls_inst        : ex2ls_inst_r;
    assign pipe_pc          = ex2ls_real ? ex2ls_pc          : ex2ls_pc_r;
    assign pipe_pc_nxt      = ex2ls_real ? ex2ls_pc_nxt      : ex2ls_pc_nxt_r;
    assign pipe_has_excp    = ex2ls_real ? ex2ls_has_excp    : ex2ls_has_excp_r;
    assign pipe_acc_fault   = ex2ls_real ? ex2ls_acc_fault   : ex2ls_acc_fault_r;
    assign pipe_mis_align   = ex2ls_real ? ex2ls_mis_align   : ex2ls_mis_align_r;
    assign pipe_ill_inst    = ex2ls_real ? ex2ls_ill_inst    : ex2ls_ill_inst_r;
    assign pipe_env_call    = ex2ls_real ? ex2ls_env_call    : ex2ls_env_call_r;
    assign pipe_env_break   = ex2ls_real ? ex2ls_env_break   : ex2ls_env_break_r;

    // Memory access.
    assign ls2mem_req_vld   = ex2ls_vld & (~pipe_has_excp)
                            & ((pipe_wb_act & pipe_op_load) | pipe_op_store);
    assign ls2mem_req_read  = ~pipe_op_store;
    assign ls2mem_req_addr  = pipe_op_store ? pipe_st_addr : pipe_ld_addr;
    assign ls2mem_req_mask  = pipe_ls_mask;
    assign ls2mem_req_data  = st_rs2_frm_wb ? wb_data : pipe_st_data;
    assign ls2mem_rsp_rdy   = 1'b1;

    assign mem_req_read     = mem_req_fire ? ls2mem_req_read : mem_ld_req_r;
    assign mem_req_fire     = ls2mem_req_vld & ls2mem_req_rdy;
    assign mem_rsp_fire     = ls2mem_rsp_vld & ls2mem_rsp_rdy;
    assign mem_ld_fire      = mem_ld_req_r & mem_rsp_fire;
    assign mem_ld_wait      = mem_ld_req_r & (~mem_ld_fire);
    assign mem_st_fire      = mem_st_req_r & mem_rsp_fire;
    assign mem_st_wait      = mem_st_req_r & (~mem_st_fire);

    generate
        if (XLEN == 32) begin: gen_ld_sign_32
            assign mem_ld_sign  = mem_ld_usgn_p ? 1'b0
                                : mem_ld_mask_p[3] ? ls2mem_rsp_data[31]
                                : mem_ld_mask_p[1] ? ls2mem_rsp_data[15]
                                : ls2mem_rsp_data[7];
        end
        else begin: gen_ld_sign_64
            assign mem_ld_sign  = mem_ld_usgn_p ? 1'b0
                                : mem_ld_mask_p[7] ? ls2mem_rsp_data[63]
                                : mem_ld_mask_p[3] ? ls2mem_rsp_data[31]
                                : mem_ld_mask_p[1] ? ls2mem_rsp_data[15]
                                : ls2mem_rsp_data[7];
        end
    endgenerate
    
    // Get forwarding state.
    assign st_rs2_frm_wb    = pipe_op_store && wb_vld && (ex2ls_rs2_idx == wb_idx_r);
    
    // Generate write-back data from memory.
    // FIXME: 1s must be adjacent and at the low-order bits now!
    generate
        for (i = 0; i < MLEN; i = i + 1) begin: gen_mem_wb_data
            assign msk_ld_data[8*(i+1)-1:8*i] = mem_ld_mask_p[i] ? ls2mem_rsp_data[8*(i+1)-1:8*i] : {8{mem_ld_sign}};
        end
    endgenerate
    
    assign mem_wb_data = mem_ld_fire ? msk_ld_data : mem_ld_data_r;
    
    // Buffer handshake firing.
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

    // Buffer input.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            ex2ls_op_load_r     <= 1'b0;
            ex2ls_op_loadu_r    <= 1'b0;
            ex2ls_op_store_r    <= 1'b0;
            ex2ls_ls_mask_r     <= {MLEN{1'b0}};
            ex2ls_ld_addr_r     <= {ALEN{1'b0}};
            ex2ls_st_addr_r     <= {ALEN{1'b0}};
            ex2ls_st_data_r     <= {XLEN{1'b0}};
            ex2ls_op_mret_r     <= 1'b0;
            ex2ls_op_wfi_r      <= 1'b0;
            ex2ls_wb_act_r      <= 1'b0;
            ex2ls_wb_vld_r      <= 1'b0;
            ex2ls_wb_idx_r      <= 5'b0;
            ex2ls_wb_data_r     <= {XLEN{1'b0}};
            ex2ls_csr_vld_r     <= 1'b0;
            ex2ls_csr_idx_r     <= 12'b0;
            ex2ls_csr_data_r    <= {XLEN{1'b0}};
            ex2ls_inst_r        <= {ILEN{1'b0}};
            ex2ls_pc_r          <= {ALEN{1'b0}};
            ex2ls_pc_nxt_r      <= {ALEN{1'b0}};
            ex2ls_has_excp_r    <= 1'b0;
            ex2ls_acc_fault_r   <= 1'b0;
            ex2ls_mis_align_r   <= 1'b0;
            ex2ls_ill_inst_r    <= 1'b0;
            ex2ls_env_call_r    <= 1'b0;
            ex2ls_env_break_r   <= 1'b0;
        end
        else begin
            if (ex2ls_real) begin
                ex2ls_op_load_r     <= #UDLY ex2ls_op_load;
                ex2ls_op_loadu_r    <= #UDLY ex2ls_op_loadu;
                ex2ls_op_store_r    <= #UDLY ex2ls_op_store;
                ex2ls_ls_mask_r     <= #UDLY ex2ls_ls_mask;
                ex2ls_ld_addr_r     <= #UDLY ex2ls_ld_addr;
                ex2ls_st_addr_r     <= #UDLY ex2ls_st_addr;
                ex2ls_st_data_r     <= #UDLY ex2ls_st_data;
                ex2ls_op_mret_r     <= #UDLY ex2ls_op_mret;
                ex2ls_op_wfi_r      <= #UDLY ex2ls_op_wfi;
                ex2ls_wb_act_r      <= #UDLY ex2ls_wb_act; 
                ex2ls_wb_vld_r      <= #UDLY ex2ls_wb_vld; 
                ex2ls_wb_idx_r      <= #UDLY ex2ls_wb_idx; 
                ex2ls_wb_data_r     <= #UDLY ex2ls_wb_data;
                ex2ls_csr_vld_r     <= #UDLY ex2ls_csr_vld;
                ex2ls_csr_idx_r     <= #UDLY ex2ls_csr_idx;
                ex2ls_csr_data_r    <= #UDLY ex2ls_csr_data;
                ex2ls_inst_r        <= #UDLY ex2ls_inst;
                ex2ls_pc_r          <= #UDLY ex2ls_pc;
                ex2ls_pc_nxt_r      <= #UDLY ex2ls_pc_nxt;
                ex2ls_has_excp_r    <= #UDLY ex2ls_has_excp;
                ex2ls_acc_fault_r   <= #UDLY ex2ls_acc_fault;
                ex2ls_mis_align_r   <= #UDLY ex2ls_mis_align;
                ex2ls_ill_inst_r    <= #UDLY ex2ls_ill_inst;
                ex2ls_env_call_r    <= #UDLY ex2ls_env_call;
                ex2ls_env_break_r   <= #UDLY ex2ls_env_break;
            end
        end
    end

    // Buffer load request status.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            mem_ld_req_r <= 1'b0;
        end
        else begin
            if (mem_req_fire & ls2mem_req_read) begin
                mem_ld_req_r <= #UDLY 1'b1;
            end
            else if (mem_ld_fire) begin
                mem_ld_req_r <= #UDLY 1'b0;
            end
        end
    end

    // Buffer store request status.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            mem_st_req_r <= 1'b0;
        end
        else begin
            if (mem_req_fire & (~ls2mem_req_read)) begin
                mem_st_req_r <= #UDLY 1'b1;
            end
            else if (mem_st_fire) begin
                mem_st_req_r <= #UDLY 1'b0;
            end
        end
    end

    // Delay load states.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            mem_ld_mask_p <= {MLEN{1'b0}};
            mem_ld_usgn_p <= 1'b0;
        end
        else begin
            if (mem_req_fire & ls2mem_req_read) begin
                mem_ld_mask_p <= #UDLY pipe_ls_mask;
                mem_ld_usgn_p <= #UDLY pipe_op_loadu;
            end
        end
    end
    
    // Buffer load data.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            mem_ld_data_r <= {XLEN{1'b0}};
        end
        else begin
            if (mem_ld_fire) begin
                mem_ld_data_r <= #UDLY msk_ld_data;
            end
        end
    end

    // Buffer commit control.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            ls2cm_vld_r <= 1'b0;
        end
        else begin
            if (ex2ls_fire & (~pipe_flush)) begin
                ls2cm_vld_r <= #UDLY 1'b1;
            end
            else begin
                ls2cm_vld_r <= #UDLY 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            inst_non_ls_r <= 1'b0;
            trap_exit_r   <= 1'b0;
            wfi_r         <= 1'b0;
        end
        else begin
            if (pipe_nxt) begin
                inst_non_ls_r <= #UDLY (~ex2ls_op_load) & (~ex2ls_op_store);
                trap_exit_r   <= #UDLY pipe_op_mret;
                wfi_r         <= #UDLY pipe_op_wfi;
            end
        end
    end

    assign ls2cm_vld         = ls2cm_vld_r & (~pipe_flush)
                             & (mem_ld_fire | mem_st_fire | inst_non_ls_r);
    assign ls2cm_trap_exit   = trap_exit_r;
    assign ls2cm_wfi         = wfi_r;
    
    // Buffer write back states.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            wb_vld_r  <= 1'b0;
            wb_data_r <= {XLEN{1'b0}};
        end
        else begin
            if (ex2ls_fire) begin
                wb_vld_r  <= #UDLY pipe_wb_act & pipe_wb_vld;
                wb_data_r <= #UDLY pipe_wb_data;
            end
            else begin
                wb_vld_r  <= #UDLY 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            wb_act_r  <= 1'b0;
            wb_idx_r  <= 5'b0;
        end
        else begin
            if (pipe_nxt) begin
                wb_act_r  <= #UDLY pipe_wb_act;
                if (pipe_wb_act) begin
                    wb_idx_r <= #UDLY pipe_wb_idx;
                end
            end
        end
    end

    assign wb_act               = wb_act_r;
    assign wb_idx               = wb_idx_r;
    assign wb_vld               = (wb_vld_r | mem_ld_fire) & (~pipe_flush);
    assign wb_data              = wb_vld_r ? wb_data_r : mem_wb_data;

    assign ls2cm_wb_act         = wb_act;
    assign ls2cm_wb_vld         = wb_vld;
    assign ls2cm_wb_idx         = wb_idx;
    assign ls2cm_wb_data        = wb_data;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            csr_vld_r  <= 1'b0;
            csr_idx_r  <= 12'b0;
            csr_data_r <= {XLEN{1'b0}};
        end
        else begin
            if (ex2ls_fire) begin
                csr_vld_r  <= #UDLY pipe_csr_vld;
                csr_idx_r  <= #UDLY pipe_csr_idx;
                csr_data_r <= #UDLY pipe_csr_data;
            end
            else begin
                csr_vld_r  <= #UDLY 1'b0;
            end
        end
    end

    assign ls2cm_csr_vld  = csr_vld_r;
    assign ls2cm_csr_idx  = csr_idx_r;
    assign ls2cm_csr_data = csr_data_r;

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
                pc_nxt_r <= #UDLY pipe_pc_nxt;
            end
        end
    end

    assign ls2cm_inst   = inst_r;
    assign ls2cm_pc     = pc_r;
    assign ls2cm_pc_nxt = pc_nxt_r;

    // Buffer load/store address.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            ls_addr_r <= {ALEN{1'b0}};
        end
        else begin
            if (pipe_nxt) begin
                ls_addr_r <= #UDLY pipe_op_store ? pipe_st_addr : pipe_ld_addr;
            end
        end
    end

    assign ls2cm_ls_addr = ls_addr_r;

    // Buffer exceptions.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            if_acc_fault_r <= 1'b0;
            if_mis_align_r <= 1'b0;
            ill_inst_r     <= 1'b0;
            env_call_r     <= 1'b0;
            env_break_r    <= 1'b0;
        end
        else begin
            if (pipe_nxt) begin
                if_acc_fault_r <= #UDLY pipe_acc_fault;
                if_mis_align_r <= #UDLY pipe_mis_align;
                ill_inst_r     <= #UDLY pipe_ill_inst;
                env_call_r     <= #UDLY pipe_env_call;
                env_break_r    <= #UDLY pipe_env_break;
            end
        end
    end

    assign ls2cm_if_acc_fault  = if_acc_fault_r;
    assign ls2cm_if_mis_align  = if_mis_align_r;
    assign ls2cm_ld_acc_fault  = mem_ld_fire ? ls2mem_rsp_excp[0] : 1'b0;
    assign ls2cm_ld_mis_align  = mem_ld_fire ? ls2mem_rsp_excp[1] : 1'b0;
    assign ls2cm_st_acc_fault  = mem_st_fire ? ls2mem_rsp_excp[0] : 1'b0;
    assign ls2cm_st_mis_align  = mem_st_fire ? ls2mem_rsp_excp[1] : 1'b0;
    assign ls2cm_ill_inst      = ill_inst_r;
    assign ls2cm_env_call      = env_call_r;
    assign ls2cm_env_break     = env_break_r;
    
endmodule

//************************************************************
// See LICENSE for license details.
//
// Module: uv_csr
//
// Designer: Owen
//
// Description:
//      Control & Status Registers (machine-level only).
//************************************************************

`timescale 1ns / 1ps

module uv_csr
#(
    parameter XLEN          = 32,
    parameter ARCH_ID       = 0,
    parameter IMPL_ID       = 0,
    parameter HART_ID       = 0,
    parameter VENDOR_ID     = 0
    
)
(
    input                   clk,
    input                   rst_n,
    
    // CSR read-write ports.
    input                   csr_rd_vld,
    input                   csr_wb_act,
    input  [11:0]           csr_rd_idx,
    output [XLEN-1:0]       csr_rd_data,

    input                   csr_wr_vld,
    input  [11:0]           csr_wr_idx,
    input  [XLEN-1:0]       csr_wr_data,

    // Non-inst ctrl & stat.
    input                   dbg_mode,
    input  [1:0]            pri_level,
    input  [63:0]           map_mtime,

    input                   trap_trig,
    input                   trap_exit,
    input                   trap_type,  // 1 for interrupt & 0 for exception.
    input  [3:0]            trap_code,
    input  [XLEN-1:0]       trap_mepc,
    input  [XLEN-1:0]       trap_info,

    input                   intr_ext,
    input                   intr_sft,
    input                   intr_tmr,

    input                   instret_inc,

    output                  out_misa_ie,    // 1 for RVI and 0 for RVE.
    output [XLEN-1:0]       out_mepc,
    output [XLEN-1:0]       out_mtvec,
    output                  out_mstatus_mie,
    output                  out_mie_meie,
    output                  out_mie_msie,
    output                  out_mie_mtie,

    output                  csr_excp
);

    localparam UDLY         = 1;
    localparam MXLEN        = XLEN;
    localparam DEF_CNT_HIB  = 1'b1;
    genvar i;
    
    // Address decoding.
    wire [1:0]              rd_rw_flag;
    wire [1:0]              wr_rw_flag;
    wire [1:0]              rd_pri_flag;
    wire [1:0]              wr_pri_flag;
    wire [7:0]              csr_rd_addr;
    wire [7:0]              csr_wr_addr;

    reg                     csr_ad_vld;
    wire                    csr_rw_flag_0;
    wire                    csr_rw_flag_1;
    wire                    csr_rw_flag_2;
    wire                    csr_rw_flag_3;
    wire                    csr_read_only;
    wire                    csr_read_write;

    wire                    csr_rd_ulevel;
    wire                    csr_rd_slevel;
    wire                    csr_rd_hlevel;
    wire                    csr_rd_mlevel;
    wire                    csr_wr_ulevel;
    wire                    csr_wr_slevel;
    wire                    csr_wr_hlevel;
    wire                    csr_wr_mlevel;

    wire                    hart_at_ulevel;
    wire                    hart_at_slevel;
    wire                    hart_at_hlevel;
    wire                    hart_at_mlevel;

    wire                    op_mvendorid;
    wire                    op_marchid;
    wire                    op_mimpid;
    wire                    op_mhartid;

    wire                    op_mstatus;
    wire                    op_misa;
    wire                    op_medeleg;
    wire                    op_mideleg;
    wire                    op_mie;
    wire                    op_mtvec;
    wire                    op_mcounteren;
    wire                    op_mstatush;

    wire                    op_mscratch;
    wire                    op_mepc;
    wire                    op_mcause;
    wire                    op_mtval;
    wire                    op_mip;
    wire                    op_mtinst;
    wire                    op_mtval2;

    wire                    op_pmpcfgs;
    wire                    op_pmpaddrs;

    wire                    op_mcycle;
    wire                    op_minstret;
    wire                    op_mhpmcounters;
    wire                    op_mcycleh;
    wire                    op_minstreth;
    wire                    op_mhpmcounterhs;

    wire                    op_mcountinhibit;
    wire                    op_mhpmevents;

    wire                    op_tselect;
    wire                    op_tdata1;
    wire                    op_tdata2;
    wire                    op_tdata3;

    wire                    op_dcsr;
    wire                    op_dpc;
    wire                    op_dscratch0;
    wire                    op_dscratch1;

    // CSR values.
    reg  [XLEN-1:0]         csr_rd_val;
    wire [XLEN-1:0]         csr_wr_val;

    // CSR fields.
    wire                    mie_msie;
    wire                    mie_mtie;
    wire                    mie_meie;
    wire                    mip_msip;
    wire                    mip_mtip;
    wire                    mip_meip;

    // Interrupt preprocess.
    reg                     intr_ext_p;
    reg                     intr_tmr_p;
    reg                     intr_sft_p;

    wire                    meip_set;
    wire                    mtip_set;
    wire                    msip_set;

    wire                    meip_clr;
    wire                    mtip_clr;
    wire                    msip_clr;

    //----------------------------------------------
    // Register Definitions.

    // User-level counters.
    wire [63:0]             ucycle;
    wire [63:0]             utime;
    wire [63:0]             uinstret;

    // Hardware performance counters (reserved for TMA in future impl).
    wire [63:0]             hpmcounters[0:28];

    // Machine information.
    wire [31:0]             mvendorid;
    wire [MXLEN-1:0]        marchid;
    wire [MXLEN-1:0]        mimpid;
    wire [MXLEN-1:0]        mhartid;

    // Machine trap setup.
    reg  [MXLEN-1:0]        mstatus;
    reg  [MXLEN-1:0]        misa;
    reg  [MXLEN-1:0]        mie;
    reg  [MXLEN-1:0]        mtvec;

    wire [31:0]             mcounteren;
    wire [MXLEN-1:0]        mstatush;
    wire [MXLEN-1:0]        medeleg;
    wire [MXLEN-1:0]        mideleg;

    // Machine trap handling.
    reg  [MXLEN-1:0]        mscratch;
    reg  [MXLEN-1:0]        mepc;
    reg  [MXLEN-1:0]        mcause;
    reg  [MXLEN-1:0]        mtval;
    reg  [MXLEN-1:0]        mip;

    wire [MXLEN-1:0]        mtinst;
    wire [MXLEN-1:0]        mtval2;

    // Machine memory protection.
    wire [MXLEN-1:0]        pmpcfgs [0:15];
    wire [MXLEN-1:0]        pmpaddrs[0:63];

    // Machine counter & timers.
    reg  [63:0]             mcycle;
    reg  [63:0]             minstret;
    wire [63:0]             mhpmcounters[0:28];

    // Machine counter setup.
    reg  [31:0]             mcountinhibit;
    wire [MXLEN-1:0]        mhpmevents[0:28];

    // For debug & trace.
    wire [MXLEN-1:0]        tselect;
    wire [MXLEN-1:0]        tdata1;
    wire [MXLEN-1:0]        tdata2;
    wire [MXLEN-1:0]        tdata3;

    // For debug only.
    wire [MXLEN-1:0]        dcsr;
    wire [MXLEN-1:0]        dpc;
    wire [MXLEN-1:0]        dscratch0;
    wire [MXLEN-1:0]        dscratch1;

    // Exception for CSR inst itself.
    wire                    excp_non_exist;
    wire                    excp_pri_level;
    wire                    excp_wr_ro_csr;

    //---------------------------------------
    // Operation Logics.

    // Decode CSR index.
    assign rd_rw_flag       = csr_rd_idx[11:10];
    assign wr_rw_flag       = csr_wr_idx[11:10];
    assign rd_pri_flag      = csr_rd_idx[9:8];
    assign wr_pri_flag      = csr_wr_idx[9:8];
    assign csr_rd_addr      = csr_rd_idx[7:0];
    assign csr_wr_addr      = csr_wr_idx[7:0];

    assign csr_rw_flag_0    = wr_rw_flag == 2'b00;
    assign csr_rw_flag_1    = wr_rw_flag == 2'b01;
    assign csr_rw_flag_2    = wr_rw_flag == 2'b10;
    assign csr_rw_flag_3    = wr_rw_flag == 2'b11;
    assign csr_read_only    = rd_rw_flag == 2'b11;
    assign csr_read_write   = ~csr_read_only;

    assign csr_rd_ulevel    = rd_pri_flag == 2'b00;
    assign csr_rd_slevel    = (pri_level >= 2'b01) && (rd_pri_flag == 2'b01);
    assign csr_rd_hlevel    = (pri_level >= 2'b10) && (rd_pri_flag == 2'b10);
    assign csr_rd_mlevel    = (pri_level == 2'b11) && (rd_pri_flag == 2'b11);
    assign csr_wr_ulevel    = wr_pri_flag == 2'b00;
    assign csr_wr_slevel    = (pri_level >= 2'b01) && (wr_pri_flag == 2'b01);
    assign csr_wr_hlevel    = (pri_level >= 2'b10) && (wr_pri_flag == 2'b10);
    assign csr_wr_mlevel    = (pri_level == 2'b11) && (wr_pri_flag == 2'b11);

    assign hart_at_ulevel   = pri_level == 2'b00;
    assign hart_at_slevel   = pri_level == 2'b01;
    assign hart_at_hlevel   = pri_level == 2'b10;
    assign hart_at_mlevel   = pri_level == 2'b11;

    assign op_mvendorid     = csr_rw_flag_3 && csr_wr_mlevel && (csr_wr_addr == 8'h11);
    assign op_marchid       = csr_rw_flag_3 && csr_wr_mlevel && (csr_wr_addr == 8'h12);
    assign op_mimpid        = csr_rw_flag_3 && csr_wr_mlevel && (csr_wr_addr == 8'h13);
    assign op_mhartid       = csr_rw_flag_3 && csr_wr_mlevel && (csr_wr_addr == 8'h14);

    assign op_mstatus       = csr_rw_flag_0 && csr_wr_mlevel && (csr_wr_addr == 8'h00);
    assign op_misa          = csr_rw_flag_0 && csr_wr_mlevel && (csr_wr_addr == 8'h01);
    assign op_medeleg       = csr_rw_flag_0 && csr_wr_mlevel && (csr_wr_addr == 8'h02);
    assign op_mideleg       = csr_rw_flag_0 && csr_wr_mlevel && (csr_wr_addr == 8'h03);
    assign op_mie           = csr_rw_flag_0 && csr_wr_mlevel && (csr_wr_addr == 8'h04);
    assign op_mtvec         = csr_rw_flag_0 && csr_wr_mlevel && (csr_wr_addr == 8'h05);
    assign op_mcounteren    = csr_rw_flag_0 && csr_wr_mlevel && (csr_wr_addr == 8'h06);
    assign op_mstatush      = csr_rw_flag_0 && csr_wr_mlevel && (csr_wr_addr == 8'h10);

    assign op_mscratch      = csr_rw_flag_0 && csr_wr_mlevel && (csr_wr_addr == 8'h40);
    assign op_mepc          = csr_rw_flag_0 && csr_wr_mlevel && (csr_wr_addr == 8'h41);
    assign op_mcause        = csr_rw_flag_0 && csr_wr_mlevel && (csr_wr_addr == 8'h42);
    assign op_mtval         = csr_rw_flag_0 && csr_wr_mlevel && (csr_wr_addr == 8'h43);
    assign op_mip           = csr_rw_flag_0 && csr_wr_mlevel && (csr_wr_addr == 8'h44);
    assign op_mtinst        = csr_rw_flag_0 && csr_wr_mlevel && (csr_wr_addr == 8'h4A);
    assign op_mtval2        = csr_rw_flag_0 && csr_wr_mlevel && (csr_wr_addr == 8'h4B);

    assign op_pmpcfgs       = csr_rw_flag_0 && csr_wr_mlevel && (csr_wr_addr[7:4] == 4'hA);
    assign op_pmpaddrs      = csr_rw_flag_0 && csr_wr_mlevel && (csr_wr_addr[7:4] >= 4'hB)
                                                             && (csr_wr_addr[7:4] <= 4'hE);

    assign op_mcycle        = csr_rw_flag_2 && csr_wr_mlevel && (csr_wr_addr == 8'h00);
    assign op_minstret      = csr_rw_flag_2 && csr_wr_mlevel && (csr_wr_addr == 8'h02);
    assign op_mhpmcounters  = csr_rw_flag_2 && csr_wr_mlevel && (csr_wr_addr >= 8'h03)
                                                             && (csr_wr_addr <= 8'h1F);

    generate
        if (XLEN == 32) begin: gen_op_mcnth_32
            assign op_mcycleh       = csr_rw_flag_2 && csr_wr_mlevel && (csr_wr_addr == 8'h80);
            assign op_minstreth     = csr_rw_flag_2 && csr_wr_mlevel && (csr_wr_addr == 8'h82);
            assign op_mhpmcounterhs = csr_rw_flag_2 && csr_wr_mlevel && (csr_wr_addr >= 8'h83)
                                                                     && (csr_wr_addr <= 8'h9F);
        end
        else begin: gen_op_mcnth_64
            assign op_mcycleh       = 1'b0;
            assign op_minstreth     = 1'b0;
            assign op_mhpmcounterhs = 1'b0;
        end
    endgenerate

    assign op_mcountinhibit = csr_rw_flag_0 && csr_wr_mlevel && (csr_wr_addr == 8'h20);
    assign op_mhpmevents    = csr_rw_flag_0 && csr_wr_mlevel && (csr_wr_addr >= 8'h23)
                                                             && (csr_wr_addr <= 8'h3F);

    assign op_tselect       = csr_rw_flag_1 && (csr_wr_mlevel | dbg_mode)
                                            && (csr_wr_addr == 8'hA0);
    assign op_tdata1        = csr_rw_flag_1 && (csr_wr_mlevel | dbg_mode)
                                            && (csr_wr_addr == 8'hA1);
    assign op_tdata2        = csr_rw_flag_1 && (csr_wr_mlevel | dbg_mode)
                                            && (csr_wr_addr == 8'hA2);
    assign op_tdata3        = csr_rw_flag_1 && (csr_wr_mlevel | dbg_mode)
                                            && (csr_wr_addr == 8'hA3);

    assign op_dcsr          = csr_rw_flag_1 && dbg_mode && (csr_wr_addr == 8'hB0);
    assign op_dpc           = csr_rw_flag_1 && dbg_mode && (csr_wr_addr == 8'hB1);
    assign op_dscratch0     = csr_rw_flag_1 && dbg_mode && (csr_wr_addr == 8'hB2);
    assign op_dscratch1     = csr_rw_flag_1 && dbg_mode && (csr_wr_addr == 8'hB3);

    // Output exceptions for CSR itself.
    assign excp_non_exist   = csr_rd_vld && (~csr_ad_vld);
    assign excp_pri_level   = csr_rd_vld && (pri_level < 2'b11) && (rd_pri_flag == 2'b11);
    assign excp_wr_ro_csr   = csr_rd_vld && csr_wb_act && csr_read_only;
    assign csr_excp         = excp_non_exist | excp_pri_level | excp_wr_ro_csr;

    // Output status.
    assign out_misa_ie      = misa[8];
    assign out_mepc         = mepc;
    assign out_mtvec        = mtvec;
    assign out_mstatus_mie  = mstatus[3];
    assign out_mie_meie     = mie_meie;
    assign out_mie_msie     = mie_msie;
    assign out_mie_mtie     = mie_mtie;

    // Output read value.
    assign csr_rd_data      = csr_rd_val;

    // Get CSR written value.
    assign csr_wr_val       = csr_wr_data;

    // Get CSR fields.
    assign mie_meie         = mie[11];
    assign mie_mtie         = mie[7];
    assign mie_msie         = mie[3];
    assign mip_meip         = mip[11];
    assign mip_mtip         = mip[7];
    assign mip_msip         = mip[3];

    // Preprocess interrupts.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            intr_ext_p <= 1'b0;
            intr_tmr_p <= 1'b0;
            intr_sft_p <= 1'b0;
        end
        else begin
            intr_ext_p <= #UDLY intr_ext;
            intr_tmr_p <= #UDLY intr_tmr;
            intr_sft_p <= #UDLY intr_sft;
        end
    end

    assign meip_set         = intr_ext & (~intr_ext_p);
    assign mtip_set         = intr_tmr & (~intr_tmr_p);
    assign msip_set         = intr_sft & (~intr_sft_p);

    assign meip_clr         = (~intr_ext) & intr_ext_p;
    assign mtip_clr         = (~intr_ext) & intr_ext_p;
    assign msip_clr         = (~intr_ext) & intr_ext_p;

    // Shadow CSRs.
    assign ucycle           = mcycle;
    assign utime            = map_mtime;
    assign uinstret         = minstret;

    generate
        for (i = 0; i <= 28; i = i + 1) begin: gen_shadow_hpm
            assign hpmcounters[i] = mhpmcounters[i];
        end
    endgenerate

    // Tie fixed registers.
    assign mvendorid        = VENDOR_ID[31:0];
    assign marchid          = ARCH_ID[MXLEN-1:0];
    assign mimpid           = IMPL_ID[MXLEN-1:0];
    assign mhartid          = HART_ID[MXLEN-1:0];

    assign mstatush         = {MXLEN{1'b0}};
    assign medeleg          = {MXLEN{1'b0}};
    assign mideleg          = {MXLEN{1'b0}};
    assign mcounteren       = 32'b0;
    assign mtinst           = {MXLEN{1'b0}};
    assign mtval2           = {MXLEN{1'b0}};

    assign tselect          = {MXLEN{1'b0}};
    assign tdata1           = {MXLEN{1'b0}};
    assign tdata2           = {MXLEN{1'b0}};
    assign tdata3           = {MXLEN{1'b0}};

    assign dcsr             = {MXLEN{1'b0}};
    assign dpc              = {MXLEN{1'b0}};
    assign dscratch0        = {MXLEN{1'b0}};
    assign dscratch1        = {MXLEN{1'b0}};

    generate
        for (i = 0; i <= 15; i = i + 1) begin: gen_pmpcfgs
            assign pmpcfgs[i] = {MXLEN{1'b0}};
        end
    endgenerate

    generate
        for (i = 0; i <= 63; i = i + 1) begin: gen_pmpaddrs
            assign pmpaddrs[i] = {MXLEN{1'b0}};
        end
    endgenerate

    // Operate on mcycle.
    generate
        if (XLEN == 32) begin: gen_mcycle_32
            always @(posedge clk or negedge rst_n) begin
                if (~rst_n) begin
                    mcycle <= 64'd0;
                end
                else begin
                    if (csr_wr_vld & op_mcycle) begin
                        mcycle[31:0]  <= #UDLY csr_wr_val;
                    end
                    else if (csr_wr_vld & op_mcycleh) begin
                        mcycle[63:32] <= #UDLY csr_wr_val;
                    end
                    else if (~mcountinhibit[0]) begin
                        mcycle <= #UDLY mcycle + 1'b1;
                    end
                end
            end
        end
        else begin: gen_mcycle_64
            always @(posedge clk or negedge rst_n) begin
                if (~rst_n) begin
                    mcycle <= 64'd0;
                end
                else begin
                    if (csr_wr_vld & op_mcycle) begin
                        mcycle <= #UDLY csr_wr_val;
                    end
                    else if (~mcountinhibit[0]) begin
                        mcycle <= #UDLY mcycle + 1'b1;
                    end
                end
            end
        end
    endgenerate

    // Operate on minstret.
    generate
        if (XLEN == 32) begin: gen_minstret_32
            always @(posedge clk or negedge rst_n) begin
                if (~rst_n) begin
                    minstret <= 64'd0;
                end
                else begin
                    if (csr_wr_vld & op_minstret) begin
                        minstret[31:0]  <= #UDLY csr_wr_val;
                    end
                    else if (csr_wr_vld & op_minstreth) begin
                        minstret[63:32] <= #UDLY csr_wr_val;
                    end
                    else if (instret_inc & (~mcountinhibit[2])) begin
                        minstret <= #UDLY minstret + 1'b1;
                    end
                end
            end
        end
        else begin: gen_minstret_64
            always @(posedge clk or negedge rst_n) begin
                if (~rst_n) begin
                    minstret <= 64'd0;
                end
                else begin
                    if (csr_wr_vld & op_minstret) begin
                        minstret <= #UDLY csr_wr_val;
                    end
                    else if (instret_inc & (~mcountinhibit[2])) begin
                        minstret <= #UDLY minstret + 1'b1;
                    end
                end
            end
        end
    endgenerate

    // Operate on mhpmcounters. (Reserved for future TMA machanism.)
    generate
        for (i = 0; i <= 28; i = i + 1) begin: gen_mhpmcounters
            assign mhpmcounters[i] = 64'd0;
        end
    endgenerate

    // Operate on mhpmevents. (Reserved for future TMA machanism.)
    generate
        for (i = 0; i <= 28; i = i + 1) begin: gen_mhpmevents
            assign mhpmevents[i] = {MXLEN{1'b0}};
        end
    endgenerate

    // Operate on mcountinhibit.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            mcountinhibit[31:2] <= {30{DEF_CNT_HIB}};
            mcountinhibit[1]    <= 1'b0;
            mcountinhibit[0]    <= DEF_CNT_HIB;
        end
        else begin
            if (csr_wr_vld & op_mcountinhibit) begin
                mcountinhibit[31:2] <= #UDLY csr_wr_val[31:2];
                mcountinhibit[0]    <= #UDLY csr_wr_val[0];
            end
        end
    end

    // Operate on misa.
    // FIXME: Enable RVE for IDU & RF read.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            misa[MXLEN-1:MXLEN-2] <= 2'b01;
            misa[MXLEN-3:26]      <= {(MXLEN-28){1'b0}};
            misa[25:0]            <= 26'b000000_000000_0100010_0000000;
        end
        else begin
            if (csr_wr_vld & op_misa) begin
                misa[4]  <= #UDLY ~csr_wr_val[8];   // RVE
                misa[8]  <= #UDLY csr_wr_val[8];    // RVI
                misa[12] <= #UDLY csr_wr_val[12];   // RVM
            end
        end
    end

    // Operate on mstatus.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            mstatus[MXLEN-1]    <= 1'b0;    // SD  ; tied to 0
            mstatus[MXLEN-2:23] <= {(MXLEN-24){1'b0}};  // WPRI, MBE, SBE, SXL, UXL; tied to 0
            mstatus[22]         <= 1'b0;    // TSR ; tied to 0
            mstatus[21]         <= 1'b0;    // TW  ; tied to 0
            mstatus[20]         <= 1'b0;    // TVM ; tied to 0
            mstatus[19]         <= 1'b0;    // MXR ; tied to 0
            mstatus[18]         <= 1'b0;    // SUM ; tied to 0
            mstatus[17]         <= 1'b0;    // MPRV; tied to 0
            mstatus[16:15]      <= 2'b0;    // XS  ; tied to 0
            mstatus[14:13]      <= 2'b0;    // FS  ; tied to 0
            mstatus[12:11]      <= 2'b11;   // MPP ; tied to 2'b11
            mstatus[10:9]       <= 2'b0;    // WPRI; tied to 0
            mstatus[8]          <= 1'b0;    // SPP ; tied to 0
            mstatus[7]          <= 1'b1;    // MPIE
            mstatus[6]          <= 1'b0;    // UBE ; tied to 0
            mstatus[5]          <= 1'b0;    // SPIE; tied to 0
            mstatus[4]          <= 1'b0;    // WPRI; tied to 0
            mstatus[3]          <= 1'b0;    // MIE
            mstatus[2]          <= 1'b0;    // WPRI; tied to 0
            mstatus[1]          <= 1'b0;    // SIE ; tied to 0
            mstatus[0]          <= 1'b0;    // WPRI; tied to 0
        end
        else begin
            if (trap_trig) begin
                mstatus[3] <= #UDLY 1'b0;
                mstatus[7] <= #UDLY mstatus[3];
            end
            else if (trap_exit) begin
                mstatus[3] <= #UDLY mstatus[7];
                mstatus[7] <= #UDLY 1'b1;
            end
            else if (csr_wr_vld & op_mstatus) begin
                mstatus[3] <= #UDLY csr_wr_val[3];
                mstatus[7] <= #UDLY csr_wr_val[7];
            end
        end
    end

    // Operate on mtvec.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            mtvec[MXLEN-1:2] <= {(MXLEN-2){1'b0}};
            mtvec[1:0]       <= 2'b00;
        end
        else begin
            if (csr_wr_vld & op_mtvec) begin
                mtvec[MXLEN-1:2] <= #UDLY csr_wr_val[MXLEN-1:2];
                // mtvec[1]      <= #UDLY csr_wr_val[1];  // mode[1] is reserved.
                mtvec[0]         <= #UDLY csr_wr_val[0];
            end
        end
    end

    // Operate on mie.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            mie[MXLEN-1:16] <= {(MXLEN-16){1'b0}};
            mie[15:12]      <= 4'b0;    // Unused; tied to 0
            mie[11]         <= 1'b0;    // MEIE
            mie[10]         <= 1'b0;    // Unused; tied to 0
            mie[9]          <= 1'b0;    // SEIE  ; tied to 0
            mie[8]          <= 1'b0;    // Unused; tied to 0
            mie[7]          <= 1'b0;    // MTIE
            mie[6]          <= 1'b0;    // Unused; tied to 0
            mie[5]          <= 1'b0;    // STIE  ; tied to 0
            mie[4]          <= 1'b0;    // Unused; tied to 0
            mie[3]          <= 1'b0;    // MSIE
            mie[2]          <= 1'b0;    // Unused; tied to 0
            mie[1]          <= 1'b0;    // SSIE  ; tied to 0
            mie[0]          <= 1'b0;    // Unused; tied to 0
        end
        else begin
            if (csr_wr_vld & op_mie) begin
                mie[11]     <= #UDLY csr_wr_val[11];
                mie[7]      <= #UDLY csr_wr_val[7];
                mie[3]      <= #UDLY csr_wr_val[3];
            end
        end
    end

    // Operate on mip.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            mip[MXLEN-1:16] <= {(MXLEN-16){1'b0}};
            mip[15:12]      <= 4'b0;    // Unused; tied to 0
            mip[11]         <= 1'b0;    // MEIP
            mip[10]         <= 1'b0;    // Unused; tied to 0
            mip[9]          <= 1'b0;    // SEIP  ; tied to 0
            mip[8]          <= 1'b0;    // Unused; tied to 0
            mip[7]          <= 1'b0;    // MTIP
            mip[6]          <= 1'b0;    // Unused; tied to 0
            mip[5]          <= 1'b0;    // STIP  ; tied to 0
            mip[4]          <= 1'b0;    // Unused; tied to 0
            mip[3]          <= 1'b0;    // MSIP
            mip[2]          <= 1'b0;    // Unused; tied to 0
            mip[1]          <= 1'b0;    // SSIP  ; tied to 0
            mip[0]          <= 1'b0;    // Unused; tied to 0
        end
        else begin
            if (hart_at_mlevel) begin
                mip[11]     <= #UDLY meip_set ? 1'b1 : meip_clr ? 1'b0 : mip_meip;
                mip[7]      <= #UDLY mtip_set ? 1'b1 : mtip_clr ? 1'b0 : mip_mtip;
                mip[3]      <= #UDLY msip_set ? 1'b1 : msip_clr ? 1'b0 : mip_msip;
            end
        end
    end

    // Operate on mscratch.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            mscratch <= {MXLEN{1'b0}};
        end
        else begin
            if (csr_wr_vld & op_mscratch) begin
                mscratch <= #UDLY csr_wr_val;
            end
        end
    end

    // Operate on mepc.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            mepc <= {MXLEN{1'b0}};
        end
        else begin
            if (trap_trig & hart_at_mlevel) begin
                mepc <= #UDLY trap_mepc;
            end
            else if (csr_wr_vld & op_mepc) begin
                mepc <= #UDLY csr_wr_val;
            end
        end
    end

    // Operate on mcause.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            mcause <= {MXLEN{1'b0}};
        end
        else begin
            if (trap_trig & hart_at_mlevel) begin
                mcause <= #UDLY {trap_type, {(MXLEN-5){1'b0}}, trap_code};
            end
            else if (csr_wr_vld & op_mcause) begin
                mcause <= #UDLY csr_wr_val;
            end
        end
    end

    // Operate on mtval.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            mtval <= {MXLEN{1'b0}};
        end
        else begin
            if (trap_trig & hart_at_mlevel) begin
                mtval <= #UDLY trap_info;
            end
            else if (csr_wr_vld & op_mtval) begin
                mtval <= #UDLY csr_wr_val;
            end
        end
    end

    //--------------------------------
    // Read CSR value.
    wire [XLEN-1:0] ucycleh;
    wire [XLEN-1:0] utimeh;
    wire [XLEN-1:0] uinstreth;
    wire [XLEN-1:0] hpmcounterhs[0:28];
    wire [XLEN-1:0] mstatush_t;
    wire [XLEN-1:0] mcycleh;
    wire [XLEN-1:0] minstreth;
    wire [XLEN-1:0] mhpmcounterhs[0:28];

    generate
        if (XLEN == 32) begin: gen_csr_high_32
            assign ucycleh      = ucycle[63:32];
            assign utimeh       = utime[63:32];
            assign uinstreth    = uinstret[63:32];
            for (i = 0; i <= 28; i = i + 1) begin: gen_hpmcnth_32
                assign hpmcounterhs[i] = hpmcounters[i][63:32];
            end
            assign mstatush_t   = mstatush;
            assign mcycleh      = mcycle[63:32];
            assign minstreth    = minstret[63:32];
            for (i = 0; i <= 28; i = i + 1) begin: gen_mhpmcnth_32
                assign mhpmcounterhs[i] = mhpmcounters[i][63:32];
            end
        end
        else begin: gen_csr_high_64
            assign ucycleh      = {XLEN{1'b0}};
            assign utimeh       = {XLEN{1'b0}};
            assign uinstreth    = {XLEN{1'b0}};
            for (i = 0; i <= 28; i = i + 1) begin: gen_hpmcnth_64
                assign hpmcounterhs[i] = {XLEN{1'b0}};
            end
            assign mstatush_t   = {XLEN{1'b0}};
            assign mcycleh      = {XLEN{1'b0}};
            assign minstreth    = {XLEN{1'b0}};
            for (i = 0; i <= 28; i = i + 1) begin: gen_mhpmcnth_64
                assign mhpmcounterhs[i] = {XLEN{1'b0}};
            end
        end
    endgenerate

    always @(*) begin
        csr_rd_val = {XLEN{1'b0}};
        csr_ad_vld = 1'b1;
        if (csr_rd_vld && (csr_rd_mlevel || dbg_mode) && (rd_rw_flag == 2'b01)) begin
            case (csr_rd_addr)
                8'hA0  : csr_rd_val = tselect;
                8'hA1  : csr_rd_val = tdata1;
                8'hA2  : csr_rd_val = tdata2;
                8'hA3  : csr_rd_val = tdata3;
                default: begin
                    csr_rd_val      = {XLEN{1'b0}};
                    csr_ad_vld      = 1'b0;
                end
            endcase
        end
        else if (csr_rd_vld && dbg_mode) begin
            case (csr_rd_addr)
                8'hB0  : csr_rd_val = dcsr;
                8'hB1  : csr_rd_val = dpc;
                8'hB2  : csr_rd_val = dscratch0;
                8'hB3  : csr_rd_val = dscratch1;
                default: begin
                    csr_rd_val      = {XLEN{1'b0}};
                    csr_ad_vld      = 1'b0;
                end
            endcase
        end
        else if (csr_rd_vld && csr_rd_ulevel && (rd_rw_flag == 2'b11)) begin
            case (csr_rd_addr)
                8'h00  : csr_rd_val = ucycle[XLEN-1:0];
                8'h01  : csr_rd_val = utime[XLEN-1:0];
                8'h02  : csr_rd_val = uinstret[XLEN-1:0];
                8'h80  : csr_rd_val = ucycleh;
                8'h81  : csr_rd_val = utimeh;
                8'h82  : csr_rd_val = uinstreth;
                default: begin
                    if ((csr_rd_addr >= 8'h03) && (csr_rd_addr <= 8'h1F)) begin
                        csr_rd_val  = hpmcounters[csr_rd_addr-8'h03][XLEN-1:0];
                    end
                    else if ((csr_rd_addr >= 8'h83) && (csr_rd_addr <= 8'h9F)) begin
                        csr_rd_val  = hpmcounterhs[csr_rd_addr-8'h83];
                    end
                    else begin
                        csr_rd_val  = {XLEN{1'b0}};
                        csr_ad_vld  = 1'b0;
                    end
                end
            endcase
        end
        else if (csr_rd_vld && csr_rd_mlevel && (rd_rw_flag == 2'b11)) begin
            case (csr_rd_addr)
                8'h11  : csr_rd_val = mvendorid;
                8'h12  : csr_rd_val = marchid;
                8'h13  : csr_rd_val = mimpid;
                8'h14  : csr_rd_val = mhartid;
                default: begin
                    csr_rd_val      = {XLEN{1'b0}};
                    csr_ad_vld      = 1'b0;
                end
            endcase
        end
        else if (csr_rd_vld && csr_rd_mlevel && (rd_rw_flag == 2'b10)) begin
            case (csr_rd_addr)
                8'h00  : csr_rd_val = mcycle;
                8'h02  : csr_rd_val = minstret;
                8'h80  : csr_rd_val = mcycleh;
                8'h82  : csr_rd_val = minstreth;
                default: begin
                    if ((csr_rd_addr >= 8'h03) && (csr_rd_addr <= 8'h1F)) begin
                        csr_rd_val  = mhpmcounters[csr_rd_addr-8'h03];
                    end
                    if ((csr_rd_addr >= 8'h83) && (csr_rd_addr <= 8'h9F)) begin
                        csr_rd_val  = mhpmcounterhs[csr_rd_addr-8'h83];
                    end
                    else begin
                        csr_rd_val  = {XLEN{1'b0}};
                        csr_ad_vld  = 1'b0;
                    end
                end
            endcase
        end
        else if (csr_rd_vld && csr_rd_mlevel && (rd_rw_flag == 2'b00)) begin
            case (csr_rd_addr)
                8'h00  : csr_rd_val = mstatus;
                8'h01  : csr_rd_val = misa;
                8'h02  : csr_rd_val = medeleg;
                8'h03  : csr_rd_val = mideleg;
                8'h04  : csr_rd_val = mie;
                8'h05  : csr_rd_val = mtvec;
                8'h06  : csr_rd_val = mcounteren;
                8'h10  : csr_rd_val = mstatush_t;
                8'h40  : csr_rd_val = mscratch;
                8'h41  : csr_rd_val = mepc;
                8'h42  : csr_rd_val = mcause;
                8'h43  : csr_rd_val = mtval;
                8'h44  : csr_rd_val = mip;
                8'h4A  : csr_rd_val = mtinst;
                8'h4B  : csr_rd_val = mtval2;
                8'h20  : csr_rd_val = mcountinhibit;
                default: begin
                    if ((csr_rd_addr >= 8'hA0) && (csr_rd_addr <= 8'hAF)) begin
                        csr_rd_val  = pmpcfgs[csr_rd_addr-8'hA0];
                    end
                    else if ((csr_rd_addr >= 8'hB0) && (csr_rd_addr <= 8'hEF)) begin
                        csr_rd_val  = pmpaddrs[csr_rd_addr-8'hB0];
                    end
                    else if ((csr_rd_addr >= 8'h23) && (csr_rd_addr <= 8'h3F)) begin
                        csr_rd_val  = mhpmevents[csr_rd_addr-8'h23];
                    end
                    else begin
                        csr_rd_val  = {XLEN{1'b0}};
                        csr_ad_vld  = 1'b0;
                    end
                end
            endcase
        end
        else begin
            csr_rd_val = {XLEN{1'b0}};
            csr_ad_vld = 1'b0;
        end
    end

endmodule

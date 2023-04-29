//************************************************************
// See LICENSE for license details.
//
// Module: uv_slc
//
// Designer: Owen
//
// Description:
//      System-level Controller.
//************************************************************

`timescale 1ns / 1ps

module uv_slc
#(
    parameter ALEN                  = 26,
    parameter DLEN                  = 32,
    parameter MLEN                  = DLEN / 8,
    parameter RST_VEC_LEN           = 32,
    parameter RST_VEC_DEF           = 64'h04000000,
    parameter EXT_IRQ_NUM           = 64,
    parameter IRQ_PRI_NUM           = 8
)
(
    input                           sys_clk,
    input                           aon_clk,
    input                           sys_rst_n,
    input                           por_rst_n,

    input                           slc_req_vld,
    output                          slc_req_rdy,
    input                           slc_req_read,
    input  [ALEN-1:0]               slc_req_addr,
    input  [MLEN-1:0]               slc_req_mask,
    input  [DLEN-1:0]               slc_req_data,

    output                          slc_rsp_vld,
    input                           slc_rsp_rdy,
    output [1:0]                    slc_rsp_excp,
    output [DLEN-1:0]               slc_rsp_data,

    input                           tmr_irq_clr,
    input  [EXT_IRQ_NUM-1:0]        ext_irq_src,

    output                          slc_rst_n,
    output [31:0]                   dev_rst_n,
    output                          gpio_mode,
    output [31:0]                   sys_icg,
    output [RST_VEC_LEN-1:0]        rst_vec,
    output                          ext_irq,
    output                          sft_irq,
    output                          tmr_irq,
    output [63:0]                   tmr_val
);

    localparam UDLY                 = 1;
    //localparam OFFSET_AW          = $clog2(DLEN / 8);
    localparam OFFSET_AW            = 2;
    localparam IRQ_ID_WIDTH         = $clog2(EXT_IRQ_NUM);
    localparam IRQ_PR_WIDTH         = $clog2(IRQ_PRI_NUM);
    localparam ADDR_DEC_WIDTH       = ALEN - OFFSET_AW;

    localparam TRIGGER_HILEVEL      = 2'b00;
    localparam TRIGGER_LOLEVEL      = 2'b01;
    localparam TRIGGER_POSEDGE      = 2'b10;
    localparam TRIGGER_NEGEDGE      = 2'b11;

    localparam REG_RST_VEC          = 0;
    localparam REG_SFT_IRQ          = 1;
    localparam REG_TMR_CFG          = 2;
    localparam REG_TMR_VAL          = 3;
    localparam REG_TMR_VALH         = 4;
    localparam REG_TMR_CMP          = 5;
    localparam REG_TMR_CMPH         = 6;
    localparam REG_SLC_RST          = 7;
    localparam REG_DEV_RST          = 8;
    localparam REG_SYS_ICG          = 9;
    localparam REG_SCRATCH          = 10;
    localparam REG_GPIO_MODE        = 11;
    localparam REG_CTRL_ADDR_MAX    = 11;

    localparam REG_EXT_IRQ_START    = 14;
    localparam REG_IRQ_CLAIM        = 14;
    localparam REG_TARGET_TH        = 15;
    localparam REG_EXT_IP_START     = REG_EXT_IRQ_START + 2;
    localparam REG_EXT_IP_NUM       = EXT_IRQ_NUM / 32 + (EXT_IRQ_NUM % 32 == 0 ? 0 : 1);
    localparam REG_EXT_IP_END       = REG_EXT_IP_START + REG_EXT_IP_NUM - 1;
    localparam REG_EXT_IE_START     = REG_EXT_IP_START + REG_EXT_IP_NUM;
    localparam REG_EXT_IE_NUM       = EXT_IRQ_NUM / 32 + (EXT_IRQ_NUM % 32 == 0 ? 0 : 1);
    localparam REG_EXT_IE_END       = REG_EXT_IE_START + REG_EXT_IE_NUM - 1;
    localparam REG_EXT_PR_START     = REG_EXT_IE_START + REG_EXT_IE_NUM;
    localparam REG_EXT_PR_NUM       = EXT_IRQ_NUM;
    localparam REG_EXT_PR_END       = REG_EXT_PR_START + REG_EXT_PR_NUM - 1;
    localparam REG_EXT_TG_START     = REG_EXT_PR_START + REG_EXT_PR_NUM;
    localparam REG_EXT_TG_NUM       = EXT_IRQ_NUM;
    localparam REG_EXT_TG_END       = REG_EXT_TG_START + REG_EXT_TG_NUM - 1;
    localparam REG_IRQ_ADDR_MAX     = REG_EXT_TG_END;

    localparam IE_IDX_WIDTH         = $clog2(REG_EXT_IE_NUM);
    localparam IP_IDX_WIDTH         = $clog2(REG_EXT_IP_NUM);
    localparam PR_IDX_WIDTH         = $clog2(REG_EXT_PR_NUM);

    genvar i, j, k;

    wire                            rst_n;
    wire [ADDR_DEC_WIDTH-1:0]       dec_addr;

    // Control registers.
    reg  [RST_VEC_LEN-1:0]          rst_vec_r;
    reg                             sft_irq_r;
    reg                             tmr_irq_r;
    reg                             tmr_cnt_r;
    reg                             tmr_auto_clr_r;
    reg  [15:0]                     tmr_clk_div_r;
    reg  [63:0]                     tmr_val_r;
    reg  [63:0]                     tmr_cmp_r;
    reg  [31:0]                     dev_rst_r;
    reg  [31:0]                     sys_icg_r;
    reg  [31:0]                     scratch_r;
    reg                             gpio_mode_r;

    reg                             dev_rst_rr;
    reg                             dev_rst_rrr;

    reg                             ext_irq_r;
    reg  [IRQ_ID_WIDTH-1:0]         sel_irq_id_r;
    reg  [IRQ_PR_WIDTH-1:0]         target_th_r;
    
    reg  [EXT_IRQ_NUM-1:0]          irq_ip_r;
    reg  [EXT_IRQ_NUM-1:0]          irq_ie_r;
    reg  [IRQ_PR_WIDTH-1:0]         irq_pr_r            [EXT_IRQ_NUM-1:0];
    reg  [1:0]                      irq_tg_r            [EXT_IRQ_NUM-1:0];
    reg  [EXT_IRQ_NUM-1:0]          irq_gate_lock_r;

    wire [IRQ_ID_WIDTH-1:0]         irq_id              [EXT_IRQ_NUM-1:0];
    wire [EXT_IRQ_NUM-1:0]          irq_id_msk          [IRQ_ID_WIDTH-1:0];

    wire [IRQ_PR_WIDTH-1:0]         irq_pr_msk          [EXT_IRQ_NUM-1:0];
    wire [IRQ_PRI_NUM-1:0]          irq_pr_msk_1hot     [EXT_IRQ_NUM-1:0];
    wire [EXT_IRQ_NUM-1:0]          irq_pr_msk_1hot_t   [IRQ_PRI_NUM-1:0];
    wire [IRQ_PRI_NUM-1:0]          irq_pr_com_1hot;
    wire [IRQ_PRI_NUM-1:0]          irq_pr_com_1hot_rev;
    wire [IRQ_PRI_NUM-1:0]          irq_pr_max_1hot_rev;
    wire [IRQ_PRI_NUM-1:0]          irq_pr_max_1hot;
    wire [EXT_IRQ_NUM-1:0]          irq_to_arb;
    wire [IRQ_ID_WIDTH-1:0]         sel_irq_id;
    wire                            sel_irq_okay;

    wire [EXT_IRQ_NUM-1:0]          irq_arb_req;
    wire [EXT_IRQ_NUM-1:0]          irq_arb_grant;

    wire [31:0]                     irq_ip_2d           [REG_EXT_IP_NUM-1:0];
    wire [31:0]                     irq_ie_2d           [REG_EXT_IE_NUM-1:0];

    // Timer operation.
    wire [63:0]                     tmr_val_add;
    wire                            tmr_cmp_geq;

    // Address decoding.
    wire                            rst_vec_match;
    wire                            sft_irq_match;
    wire                            tmr_cfg_match;
    wire                            tmr_val_match;
    wire                            tmr_valh_match;
    wire                            tmr_cmp_match;
    wire                            tmr_cmph_match;
    wire                            slc_rst_match;
    wire                            dev_rst_match;
    wire                            sys_icg_match;
    wire                            scratch_match;
    wire                            gpio_mode_match;
    wire                            irq_claim_match;
    wire                            target_th_match;
    wire                            ext_ip_match;
    wire                            ext_ie_match;
    wire                            ext_pr_match;
    wire                            ext_tg_match;
    wire [ADDR_DEC_WIDTH-1:0]       ext_ip_reg_idx;
    wire [ADDR_DEC_WIDTH-1:0]       ext_ie_reg_idx;
    wire [ADDR_DEC_WIDTH-1:0]       ext_pr_reg_idx;
    wire [ADDR_DEC_WIDTH-1:0]       ext_tg_reg_idx;
    wire                            addr_mismatch;

    wire                            rst_vec_sel;
    wire                            sft_irq_sel;
    wire                            tmr_cfg_sel;
    wire                            tmr_val_sel;
    wire                            tmr_valh_sel;
    wire                            tmr_cmp_sel;
    wire                            tmr_cmph_sel;
    wire                            slc_rst_sel;
    wire                            dev_rst_sel;
    wire                            sys_icg_sel;
    wire                            scratch_sel;
    wire                            gpio_mode_sel;
    wire                            irq_claim_sel;
    wire                            target_th_sel;
    wire                            ext_ip_sel;
    wire                            ext_ie_sel;
    wire                            ext_pr_sel;
    wire                            ext_tg_sel;

    wire                            rst_vec_wr;
    wire                            sft_irq_wr;
    wire                            tmr_cfg_wr;
    wire                            tmr_val_wr;
    wire                            tmr_valh_wr;
    wire                            tmr_cmp_wr;
    wire                            tmr_cmph_wr;
    wire                            slc_rst_wr;
    wire                            dev_rst_wr;
    wire                            sys_icg_wr;
    wire                            scratch_wr;
    wire                            gpio_mode_wr;
    wire                            irq_claim_wr;
    wire                            target_th_wr;
    wire                            ext_ie_wr;
    wire                            ext_pr_wr;
    wire                            ext_tg_wr;

    wire                            rst_vec_rd;
    wire                            sft_irq_rd;
    wire                            tmr_cfg_rd;
    wire                            tmr_val_rd;
    wire                            tmr_valh_rd;
    wire                            tmr_cmp_rd;
    wire                            tmr_cmph_rd;
    wire                            sys_icg_rd;
    wire                            scratch_rd;
    wire                            gpio_mode_rd;
    wire                            irq_claim_rd;
    wire                            target_th_rd;
    wire                            ext_ip_rd;
    wire                            ext_ie_rd;
    wire                            ext_pr_rd;
    wire                            ext_tg_rd;

    // Input interrupt sources.
    reg  [EXT_IRQ_NUM-1:0]          ext_irq_src_p;
    wire [EXT_IRQ_NUM-1:0]          ext_irq_rise;
    wire [EXT_IRQ_NUM-1:0]          ext_irq_fall;
    wire [EXT_IRQ_NUM-1:0]          ext_irq_trig;

    // Responsed ctrl & data.
    reg                             rsp_vld_r;
    reg                             rsp_excp_r;
    reg  [DLEN-1:0]                 rsp_data;
    reg  [DLEN-1:0]                 rsp_data_r;

    assign rst_n                    = sys_rst_n & por_rst_n;

    // Request always ready.
    assign slc_req_rdy              = 1'b1;

    // Match request address.
    assign dec_addr                 = slc_req_addr[ALEN-1:OFFSET_AW];
    assign rst_vec_match            = dec_addr == REG_RST_VEC  [ADDR_DEC_WIDTH-1:0];
    assign sft_irq_match            = dec_addr == REG_SFT_IRQ  [ADDR_DEC_WIDTH-1:0];
    assign tmr_cfg_match            = dec_addr == REG_TMR_CFG  [ADDR_DEC_WIDTH-1:0];
    assign tmr_val_match            = dec_addr == REG_TMR_VAL  [ADDR_DEC_WIDTH-1:0];
    assign tmr_valh_match           = dec_addr == REG_TMR_VALH [ADDR_DEC_WIDTH-1:0];
    assign tmr_cmp_match            = dec_addr == REG_TMR_CMP  [ADDR_DEC_WIDTH-1:0];
    assign tmr_cmph_match           = dec_addr == REG_TMR_CMPH [ADDR_DEC_WIDTH-1:0];
    assign slc_rst_match            = dec_addr == REG_SLC_RST  [ADDR_DEC_WIDTH-1:0];
    assign dev_rst_match            = dec_addr == REG_DEV_RST  [ADDR_DEC_WIDTH-1:0];
    assign sys_icg_match            = dec_addr == REG_SYS_ICG  [ADDR_DEC_WIDTH-1:0];
    assign scratch_match            = dec_addr == REG_SCRATCH  [ADDR_DEC_WIDTH-1:0];
    assign gpio_mode_match          = dec_addr == REG_GPIO_MODE[ADDR_DEC_WIDTH-1:0];
    assign irq_claim_match          = dec_addr == REG_IRQ_CLAIM[ADDR_DEC_WIDTH-1:0];
    assign target_th_match          = dec_addr == REG_TARGET_TH[ADDR_DEC_WIDTH-1:0];
    assign ext_ip_match             =  (dec_addr >= REG_EXT_IP_START[ADDR_DEC_WIDTH-1:0])
                                    && (dec_addr <= REG_EXT_IP_END  [ADDR_DEC_WIDTH-1:0]);
    assign ext_ie_match             =  (dec_addr >= REG_EXT_IE_START[ADDR_DEC_WIDTH-1:0])
                                    && (dec_addr <= REG_EXT_IE_END  [ADDR_DEC_WIDTH-1:0]);
    assign ext_pr_match             =  (dec_addr >= REG_EXT_PR_START[ADDR_DEC_WIDTH-1:0])
                                    && (dec_addr <= REG_EXT_PR_END  [ADDR_DEC_WIDTH-1:0]);
    assign ext_tg_match             =  (dec_addr >= REG_EXT_TG_START[ADDR_DEC_WIDTH-1:0])
                                    && (dec_addr <= REG_EXT_TG_END  [ADDR_DEC_WIDTH-1:0]);
    assign ext_ip_reg_idx           = dec_addr - REG_EXT_IP_START[ADDR_DEC_WIDTH-1:0];
    assign ext_ie_reg_idx           = dec_addr - REG_EXT_IE_START[ADDR_DEC_WIDTH-1:0];
    assign ext_pr_reg_idx           = dec_addr - REG_EXT_PR_START[ADDR_DEC_WIDTH-1:0];
    assign ext_tg_reg_idx           = dec_addr - REG_EXT_TG_START[ADDR_DEC_WIDTH-1:0];
    assign addr_mismatch            = ((dec_addr > REG_CTRL_ADDR_MAX[ADDR_DEC_WIDTH-1:0])
                                    && (dec_addr < REG_EXT_IRQ_START[ADDR_DEC_WIDTH-1:0]))
                                    || (dec_addr > REG_IRQ_ADDR_MAX[ADDR_DEC_WIDTH-1:0]);

    // Select register.
    assign rst_vec_sel              = slc_req_vld & rst_vec_match ;
    assign sft_irq_sel              = slc_req_vld & sft_irq_match ;
    assign tmr_cfg_sel              = slc_req_vld & tmr_cfg_match ;
    assign tmr_val_sel              = slc_req_vld & tmr_val_match ;
    assign tmr_valh_sel             = slc_req_vld & tmr_valh_match;
    assign tmr_cmp_sel              = slc_req_vld & tmr_cmp_match ;
    assign tmr_cmph_sel             = slc_req_vld & tmr_cmph_match;
    assign slc_rst_sel              = slc_req_vld & slc_rst_match ;
    assign dev_rst_sel              = slc_req_vld & dev_rst_match ;
    assign sys_icg_sel              = slc_req_vld & sys_icg_match ;
    assign scratch_sel              = slc_req_vld & scratch_match ;
    assign gpio_mode_sel            = slc_req_vld & gpio_mode_match;
    assign irq_claim_sel            = slc_req_vld & irq_claim_match;
    assign target_th_sel            = slc_req_vld & target_th_match;
    assign ext_ip_sel               = slc_req_vld & ext_ip_match;
    assign ext_ie_sel               = slc_req_vld & ext_ie_match;
    assign ext_pr_sel               = slc_req_vld & ext_pr_match;
    assign ext_tg_sel               = slc_req_vld & ext_tg_match;

    assign rst_vec_wr               = rst_vec_sel   & (~slc_req_read);
    assign sft_irq_wr               = sft_irq_sel   & (~slc_req_read);
    assign tmr_cfg_wr               = tmr_cfg_sel   & (~slc_req_read);
    assign tmr_val_wr               = tmr_val_sel   & (~slc_req_read);
    assign tmr_valh_wr              = tmr_valh_sel  & (~slc_req_read);
    assign tmr_cmp_wr               = tmr_cmp_sel   & (~slc_req_read);
    assign tmr_cmph_wr              = tmr_cmph_sel  & (~slc_req_read);
    assign slc_rst_wr               = slc_rst_sel   & (~slc_req_read);
    assign dev_rst_wr               = dev_rst_sel   & (~slc_req_read);
    assign sys_icg_wr               = sys_icg_sel   & (~slc_req_read);
    assign scratch_wr               = scratch_sel   & (~slc_req_read);
    assign gpio_mode_wr             = gpio_mode_sel & (~slc_req_read);
    assign irq_claim_wr             = irq_claim_sel & (~slc_req_read);
    assign target_th_wr             = target_th_sel & (~slc_req_read);
    assign ext_ie_wr                = ext_ie_sel    & (~slc_req_read);
    assign ext_pr_wr                = ext_pr_sel    & (~slc_req_read);
    assign ext_tg_wr                = ext_tg_sel    & (~slc_req_read);

    assign rst_vec_rd               = rst_vec_sel   & slc_req_read;
    assign sft_irq_rd               = sft_irq_sel   & slc_req_read;
    assign tmr_cfg_rd               = tmr_cfg_sel   & slc_req_read;
    assign tmr_val_rd               = tmr_val_sel   & slc_req_read;
    assign tmr_valh_rd              = tmr_valh_sel  & slc_req_read;
    assign tmr_cmp_rd               = tmr_cmp_sel   & slc_req_read;
    assign tmr_cmph_rd              = tmr_cmph_sel  & slc_req_read;
    assign sys_icg_rd               = sys_icg_sel   & slc_req_read;
    assign scratch_rd               = scratch_sel   & slc_req_read;
    assign gpio_mode_rd             = gpio_mode_sel & slc_req_read;
    assign irq_claim_rd             = irq_claim_sel & slc_req_read;
    assign target_th_rd             = target_th_sel & slc_req_read;
    assign ext_ip_rd                = ext_ip_sel    & slc_req_read;
    assign ext_ie_rd                = ext_ie_sel    & slc_req_read;
    assign ext_pr_rd                = ext_pr_sel    & slc_req_read;
    assign ext_tg_rd                = ext_tg_sel    & slc_req_read;

    // For timer IRQ.
    assign tmr_val_add              = tmr_val_r + 1'b1;
    assign tmr_cmp_geq              = tmr_val_add >= tmr_cmp_r;

    // For external IRQ.
    assign ext_irq_rise             = ext_irq_src & (~ext_irq_src_p);
    assign ext_irq_fall             = (~ext_irq_src) & ext_irq_src_p;
    generate
        for (i = 0; i < EXT_IRQ_NUM; i = i + 1) begin: gen_ext_irq_trig
            assign ext_irq_trig[i]  = (~irq_gate_lock_r[i])
                                    & ((irq_tg_r[i] == TRIGGER_POSEDGE) ? ext_irq_rise[i]
                                    :  (irq_tg_r[i] == TRIGGER_NEGEDGE) ? ext_irq_fall[i]
                                    :  (irq_tg_r[i] == TRIGGER_LOLEVEL) ? ~ext_irq_src[i]
                                    :  ext_irq_src[i]);
        end
    endgenerate

    // Output to core.
    assign rst_vec                  = rst_vec_r;
    assign ext_irq                  = ext_irq_r;
    assign sft_irq                  = sft_irq_r;
    assign tmr_irq                  = tmr_irq_r;
    assign tmr_val                  = tmr_val_r;

    // Output to soc.
    assign slc_rst_n                = ~slc_rst_wr;
    assign dev_rst_n                = ~(dev_rst_r | dev_rst_rr | dev_rst_rrr);
    assign gpio_mode                = gpio_mode_r;
    assign sys_icg                  = sys_icg_r;

    // Bus response.
    assign slc_rsp_vld              = rsp_vld_r;
    assign slc_rsp_excp             = {1'b0, rsp_excp_r};
    assign slc_rsp_data             = rsp_data_r;

    // Set rst_vec_r.
    generate
        for (i = 0; i < MLEN; i = i + 1) begin: gen_rst_vec_wr
            if (i * 8 < RST_VEC_LEN) begin: gen_msk_rst_vec_wr
                always @(posedge sys_clk or negedge por_rst_n) begin
                    if (~por_rst_n) begin
                        rst_vec_r[(i+1)*8-1:i*8] <= RST_VEC_DEF[(i+1)*8-1:i*8];
                    end
                    else begin
                        if (rst_vec_wr & slc_req_mask[i]) begin
                            rst_vec_r[(i+1)*8-1:i*8] <= #UDLY slc_req_data[(i+1)*8-1:i*8];
                        end
                    end
                end
            end
        end
    endgenerate

    // Set sft_irq_r.
    always @(posedge sys_clk or negedge rst_n) begin
        if (~rst_n) begin
            sft_irq_r <= 1'b0;
        end
        else begin
            if (sft_irq_wr & slc_req_mask[0]) begin
                sft_irq_r <= #UDLY slc_req_data[0];
            end
        end
    end

    // Set tmr_irq_r.
    always @(posedge aon_clk or negedge rst_n) begin
        if (~rst_n) begin
            tmr_irq_r <= 1'b0;
        end
        else begin
            if (tmr_cmp_geq) begin
                tmr_irq_r <= #UDLY 1'b1;
            end
            else if (tmr_irq_clr) begin
                tmr_irq_r <= #UDLY 1'b0;
            end
        end
    end

    // Set timer config.
    always @(posedge sys_clk or negedge rst_n) begin
        if (~rst_n) begin
            tmr_cnt_r       <= 1'b0;
            tmr_auto_clr_r  <= 1'b0;
            tmr_clk_div_r   <= 16'b0;
        end
        else begin
            if (tmr_cfg_wr) begin
                tmr_cnt_r           <= #UDLY slc_req_mask[0] ? slc_req_data[0] : tmr_cnt_r;
                tmr_auto_clr_r      <= #UDLY slc_req_mask[0] ? slc_req_data[1] : tmr_auto_clr_r;
                tmr_clk_div_r[7:0]  <= #UDLY slc_req_mask[2] ? slc_req_data[23:16] : tmr_clk_div_r[7:0];
                tmr_clk_div_r[15:8] <= #UDLY slc_req_mask[3] ? slc_req_data[31:24] : tmr_clk_div_r[15:8];
            end
        end
    end

    // Set tmr_val_r.
    generate
        if (DLEN == 32) begin: gen_tmr_val_wr_32b
            always @(posedge aon_clk or negedge rst_n) begin
                if (~rst_n) begin
                    tmr_val_r <= 64'b0;
                end
                else begin
                    if (tmr_val_wr) begin
                        tmr_val_r[7:0]   <= #UDLY slc_req_mask[0] ? slc_req_data[7:0]   : tmr_val_r[7:0]  ;
                        tmr_val_r[15:8]  <= #UDLY slc_req_mask[1] ? slc_req_data[15:8]  : tmr_val_r[15:8] ;
                        tmr_val_r[23:16] <= #UDLY slc_req_mask[2] ? slc_req_data[23:16] : tmr_val_r[23:16];
                        tmr_val_r[31:24] <= #UDLY slc_req_mask[3] ? slc_req_data[31:24] : tmr_val_r[31:24];
                    end
                    else if (tmr_valh_wr) begin
                        tmr_val_r[39:32] <= #UDLY slc_req_mask[0] ? slc_req_data[7:0]   : tmr_val_r[39:32];
                        tmr_val_r[47:40] <= #UDLY slc_req_mask[1] ? slc_req_data[15:8]  : tmr_val_r[47:40];
                        tmr_val_r[55:48] <= #UDLY slc_req_mask[2] ? slc_req_data[23:16] : tmr_val_r[55:48];
                        tmr_val_r[63:56] <= #UDLY slc_req_mask[3] ? slc_req_data[31:24] : tmr_val_r[63:56];
                    end
                    else if (tmr_cmp_geq & tmr_auto_clr_r) begin
                        tmr_val_r <= #UDLY 64'b0;
                    end
                    else if (tmr_cnt_r) begin
                        tmr_val_r <= #UDLY tmr_val_add;
                    end
                end
            end
        end
        else begin: gen_tmr_val_wr_64b
            always @(posedge aon_clk or negedge rst_n) begin
                if (~rst_n) begin
                    tmr_val_r <= 64'b0;
                end
                else begin
                    if (tmr_val_wr) begin
                        tmr_val_r[7:0]   <= #UDLY slc_req_mask[0] ? slc_req_data[7:0]   : tmr_val_r[7:0]  ;
                        tmr_val_r[15:8]  <= #UDLY slc_req_mask[1] ? slc_req_data[15:8]  : tmr_val_r[15:8] ;
                        tmr_val_r[23:16] <= #UDLY slc_req_mask[2] ? slc_req_data[23:16] : tmr_val_r[23:16];
                        tmr_val_r[31:24] <= #UDLY slc_req_mask[3] ? slc_req_data[31:24] : tmr_val_r[31:24];
                        tmr_val_r[39:32] <= #UDLY slc_req_mask[4] ? slc_req_data[39:32] : tmr_val_r[39:32];
                        tmr_val_r[47:40] <= #UDLY slc_req_mask[5] ? slc_req_data[47:40] : tmr_val_r[47:40];
                        tmr_val_r[55:48] <= #UDLY slc_req_mask[6] ? slc_req_data[55:48] : tmr_val_r[55:48];
                        tmr_val_r[63:56] <= #UDLY slc_req_mask[7] ? slc_req_data[63:56] : tmr_val_r[63:56];
                    end
                    else if (tmr_cmp_geq & tmr_auto_clr_r) begin
                        tmr_val_r <= #UDLY 64'b0;
                    end
                    else if (tmr_cnt_r) begin
                        tmr_val_r <= #UDLY tmr_val_add;
                    end
                end
            end
        end
    endgenerate

    // Set tmr_cmp_r.
    generate
        if (DLEN == 32) begin: gen_tmr_cmp_wr_32b
            always @(posedge sys_clk or negedge rst_n) begin
                if (~rst_n) begin
                    tmr_cmp_r <= {64{1'b1}};
                end
                else begin
                    if (tmr_cmp_wr) begin
                        tmr_cmp_r[7:0]   <= #UDLY slc_req_mask[0] ? slc_req_data[7:0]   : tmr_cmp_r[7:0]  ;
                        tmr_cmp_r[15:8]  <= #UDLY slc_req_mask[1] ? slc_req_data[15:8]  : tmr_cmp_r[15:8] ;
                        tmr_cmp_r[23:16] <= #UDLY slc_req_mask[2] ? slc_req_data[23:16] : tmr_cmp_r[23:16];
                        tmr_cmp_r[31:24] <= #UDLY slc_req_mask[3] ? slc_req_data[31:24] : tmr_cmp_r[31:24];
                    end
                    else if (tmr_cmph_wr) begin
                        tmr_cmp_r[39:32] <= #UDLY slc_req_mask[0] ? slc_req_data[7:0]   : tmr_cmp_r[39:32];
                        tmr_cmp_r[47:40] <= #UDLY slc_req_mask[1] ? slc_req_data[15:8]  : tmr_cmp_r[47:40];
                        tmr_cmp_r[55:48] <= #UDLY slc_req_mask[2] ? slc_req_data[23:16] : tmr_cmp_r[55:48];
                        tmr_cmp_r[63:56] <= #UDLY slc_req_mask[3] ? slc_req_data[31:24] : tmr_cmp_r[63:56];
                    end
                end
            end
        end
        else begin: gen_tmr_cmp_wr_64b
            always @(posedge sys_clk or negedge rst_n) begin
                if (~rst_n) begin
                    tmr_cmp_r <= 64'b0;
                end
                else begin
                    if (tmr_cmp_wr) begin
                        tmr_cmp_r[7:0]   <= #UDLY slc_req_mask[0] ? slc_req_data[7:0]   : tmr_cmp_r[7:0]  ;
                        tmr_cmp_r[15:8]  <= #UDLY slc_req_mask[1] ? slc_req_data[15:8]  : tmr_cmp_r[15:8] ;
                        tmr_cmp_r[23:16] <= #UDLY slc_req_mask[2] ? slc_req_data[23:16] : tmr_cmp_r[23:16];
                        tmr_cmp_r[31:24] <= #UDLY slc_req_mask[3] ? slc_req_data[31:24] : tmr_cmp_r[31:24];
                        tmr_cmp_r[39:32] <= #UDLY slc_req_mask[4] ? slc_req_data[39:32] : tmr_cmp_r[39:32];
                        tmr_cmp_r[47:40] <= #UDLY slc_req_mask[5] ? slc_req_data[47:40] : tmr_cmp_r[47:40];
                        tmr_cmp_r[55:48] <= #UDLY slc_req_mask[6] ? slc_req_data[55:48] : tmr_cmp_r[55:48];
                        tmr_cmp_r[63:56] <= #UDLY slc_req_mask[7] ? slc_req_data[63:56] : tmr_cmp_r[63:56];
                    end
                end
            end
        end
    endgenerate

    // Set dev_rst_r.
    always @(posedge sys_clk or negedge rst_n) begin
        if (~rst_n) begin
            dev_rst_r <= {32{1'b1}};
        end
        else begin
            if (dev_rst_wr) begin
                dev_rst_r[7:0]   <= #UDLY slc_req_mask[0] ? slc_req_data[7:0]   : dev_rst_r[7:0];
                dev_rst_r[15:8]  <= #UDLY slc_req_mask[1] ? slc_req_data[15:8]  : dev_rst_r[15:8];
                dev_rst_r[23:16] <= #UDLY slc_req_mask[2] ? slc_req_data[23:16] : dev_rst_r[23:16];
                dev_rst_r[31:24] <= #UDLY slc_req_mask[3] ? slc_req_data[31:24] : dev_rst_r[31:24];
            end
        end
    end

    always @(posedge sys_clk or negedge rst_n) begin
        if (~rst_n) begin
            dev_rst_rr  <= {32{1'b1}};
            dev_rst_rrr <= {32{1'b1}};
        end
        else begin
            dev_rst_rr  <= #UDLY dev_rst_r;
            dev_rst_rrr <= #UDLY dev_rst_rr;
        end
    end

    // Set sys_icg_r.
    always @(posedge sys_clk or negedge rst_n) begin
        if (~rst_n) begin
            sys_icg_r <= {32{1'b1}};
        end
        else begin
            if (sys_icg_wr) begin
                sys_icg_r[7:0]   <= #UDLY slc_req_mask[0] ? slc_req_data[7:0]   : sys_icg_r[7:0];
                sys_icg_r[15:8]  <= #UDLY slc_req_mask[1] ? slc_req_data[15:8]  : sys_icg_r[15:8];
                sys_icg_r[23:16] <= #UDLY slc_req_mask[2] ? slc_req_data[23:16] : sys_icg_r[23:16];
                sys_icg_r[31:24] <= #UDLY slc_req_mask[3] ? slc_req_data[31:24] : sys_icg_r[31:24];
            end
        end
    end

    // Set scratch_r.
    always @(posedge sys_clk or negedge rst_n) begin
        if (~rst_n) begin
            scratch_r <= {32{1'b1}};
        end
        else begin
            if (scratch_wr) begin
                scratch_r[7:0]   <= #UDLY slc_req_mask[0] ? slc_req_data[7:0]   : scratch_r[7:0];
                scratch_r[15:8]  <= #UDLY slc_req_mask[1] ? slc_req_data[15:8]  : scratch_r[15:8];
                scratch_r[23:16] <= #UDLY slc_req_mask[2] ? slc_req_data[23:16] : scratch_r[23:16];
                scratch_r[31:24] <= #UDLY slc_req_mask[3] ? slc_req_data[31:24] : scratch_r[31:24];
            end
        end
    end

    // Set gpio_mode_r.
    always @(posedge sys_clk or negedge rst_n) begin
        if (~rst_n) begin
            gpio_mode_r <= 1'b0;
        end
        else begin
            if (gpio_mode_wr) begin
                gpio_mode_r <= #UDLY slc_req_mask[0] ? slc_req_data[0] : gpio_mode_r;
            end
        end
    end

    // Generate ext IRQ ID.
    generate
        for (i = 0; i < EXT_IRQ_NUM; i = i + 1) begin: gen_ext_irq_id
            assign irq_id[i] = i[IRQ_ID_WIDTH-1:0];
        end
    endgenerate

    // Lock ext IRQ gateway.
    generate
        for (i = 0; i < EXT_IRQ_NUM; i = i + 1) begin: gen_ext_gate_lock
            always @(posedge sys_clk or negedge rst_n) begin
                if (~rst_n) begin
                    irq_gate_lock_r[i] <= 1'b0;
                end
                else begin
                    if (ext_irq_trig[i]) begin
                        irq_gate_lock_r[i] <= #UDLY 1'b1;
                    end
                    else if (irq_claim_wr && (slc_req_data[IRQ_ID_WIDTH-1:0] == i[IRQ_ID_WIDTH-1:0])) begin
                        irq_gate_lock_r[i] <= #UDLY 1'b0;
                    end
                end
            end
        end
    endgenerate

    // Delay ext IRQ sources.
    always @(posedge sys_clk or negedge rst_n) begin
        if (~rst_n) begin
            ext_irq_src_p <= {EXT_IRQ_NUM{1'b0}};
        end
        else begin
            ext_irq_src_p <= #UDLY ext_irq_src;
        end
    end

    // Select enabled IRQs.
    generate
        for (i = 0; i < EXT_IRQ_NUM; i = i + 1) begin: gen_irq_to_arb
            assign irq_to_arb[i] = irq_ip_r[i] && irq_ie_r[i] && (irq_pr_r[i] > target_th_r);
        end
    endgenerate

    // Mask IRQ priorities.
    generate
        for (i = 0; i < EXT_IRQ_NUM; i = i + 1) begin: gen_irq_pr_msk
            assign irq_pr_msk[i] = irq_to_arb[i] ? irq_pr_r[i] : {IRQ_PR_WIDTH{1'b0}};
        end
    endgenerate

    // Get the max priority.
    generate
        for (i = 0; i < EXT_IRQ_NUM; i = i + 1) begin: gen_irq_pr_msk_1hot
            assign irq_pr_msk_1hot[i] = {{(IRQ_PRI_NUM-1){1'b0}}, 1'b1} << irq_pr_msk[i];
        end
    endgenerate

    generate
        for (i = 0; i < EXT_IRQ_NUM; i = i + 1) begin: gen_irq_pr_msk_1hot_t
            for (j = 0; j < IRQ_PRI_NUM; j = j + 1) begin: gen_irq_pr_msk_1hot_t_bit
                assign irq_pr_msk_1hot_t[j][i] = irq_pr_msk_1hot[i][j];
            end
        end
    endgenerate

    generate
        for (i = 0; i < IRQ_PRI_NUM; i = i + 1) begin: gen_irq_pr_com_1hot
            assign irq_pr_com_1hot[i] = |irq_pr_msk_1hot_t[i];
        end
    endgenerate

    generate
        for (i = 0; i < IRQ_PRI_NUM; i = i + 1) begin: gen_irq_pr_com_1hot_rev
            assign irq_pr_com_1hot_rev[i] = irq_pr_com_1hot[IRQ_PRI_NUM-i-1];
        end
    endgenerate

    generate
        for (i = 0; i < IRQ_PRI_NUM; i = i + 1) begin: gen_irq_pr_max_1hot
            assign irq_pr_max_1hot[i] = irq_pr_max_1hot_rev[IRQ_PRI_NUM-i-1];
        end
    endgenerate

    // Generate arbiter request.
    generate
        for (i = 0; i < EXT_IRQ_NUM; i = i + 1) begin: gen_irq_arb_req
            assign irq_arb_req[i] = irq_to_arb[i] && (irq_pr_msk_1hot[i] >= irq_pr_max_1hot);
        end
    endgenerate

    // Select IRQ to target.
    assign sel_irq_okay = |irq_arb_grant;

    generate
        for (i = 0; i < EXT_IRQ_NUM; i = i + 1) begin: gen_irq_id_msk
            for (j = 0; j < IRQ_ID_WIDTH; j = j + 1) begin: gen_irq_id_msk_bit
                assign irq_id_msk[j][i] = irq_id[i][j] & irq_arb_grant[i];
            end
        end
    endgenerate

    generate
        for (i = 0; i < IRQ_ID_WIDTH; i = i + 1) begin: gen_sel_irq_id
            assign sel_irq_id[i] = |irq_id_msk[i];
        end
    endgenerate

    // Set IRQ ID selected by target.
    always @(posedge sys_clk or negedge rst_n) begin
        if (~rst_n) begin
            sel_irq_id_r <= {IRQ_ID_WIDTH{1'b0}};
        end
        else begin
            if (sel_irq_okay) begin
                sel_irq_id_r <= #UDLY sel_irq_id;
            end
        end
    end

    always @(posedge sys_clk or negedge rst_n) begin
        if (~rst_n) begin
            ext_irq_r <= 1'b0;
        end
        else begin
            if (irq_claim_wr && (slc_req_data[IRQ_ID_WIDTH-1:0] == sel_irq_id_r)) begin
                ext_irq_r <= #UDLY 1'b0;
            end
            else if (sel_irq_okay) begin
                ext_irq_r <= #UDLY 1'b1;
            end
        end
    end

    // Set ext IRQ target threshold.
    always @(posedge sys_clk or negedge rst_n) begin
        if (~rst_n) begin
            target_th_r <= {IRQ_PR_WIDTH{1'b0}};
        end
        else begin
            if (target_th_wr) begin
                target_th_r <= #UDLY slc_req_mask[0] ? slc_req_data[IRQ_PR_WIDTH-1:0] : target_th_r;
            end
        end
    end

    // Set ext interrupt pending.
    generate
        for (i = 0; i < EXT_IRQ_NUM; i = i + 1) begin: gen_ext_ip
            always @(posedge sys_clk or negedge rst_n) begin
                if (~rst_n) begin
                    irq_ip_r[i] <= 1'b0;
                end
                else begin
                    if (ext_irq_trig[i]) begin
                        irq_ip_r[i] <= #UDLY 1'b1;
                    end
                    else if (irq_claim_rd && (sel_irq_id_r == i[IRQ_ID_WIDTH-1:0])) begin
                        irq_ip_r[i] <= #UDLY 1'b0;
                    end
                end
            end
        end
    endgenerate

    // Set ext interrupt enabling.
    generate
        if (DLEN == 32) begin: gen_ext_ie_32b
            for (i = 0; i < REG_EXT_IE_NUM; i = i + 1) begin: gen_ext_ie
                always @(posedge sys_clk or negedge rst_n) begin
                    if (~rst_n) begin
                        irq_ie_r[(i+1)*DLEN-1:i*DLEN] <= {DLEN{1'b0}};
                    end
                    else begin
                        if (ext_ie_wr && (ext_ie_reg_idx == i[ADDR_DEC_WIDTH-1:0])) begin
                            irq_ie_r[i*DLEN+7:i*DLEN]     <= #UDLY slc_req_mask[0] ? slc_req_data[7:0]   : irq_ie_r[i*DLEN+7:i*DLEN];
                            irq_ie_r[i*DLEN+15:i*DLEN+8]  <= #UDLY slc_req_mask[1] ? slc_req_data[15:8]  : irq_ie_r[i*DLEN+15:i*DLEN+8];
                            irq_ie_r[i*DLEN+23:i*DLEN+16] <= #UDLY slc_req_mask[2] ? slc_req_data[23:16] : irq_ie_r[i*DLEN+23:i*DLEN+16];
                            irq_ie_r[i*DLEN+31:i*DLEN+24] <= #UDLY slc_req_mask[3] ? slc_req_data[31:24] : irq_ie_r[i*DLEN+31:i*DLEN+24];
                        end
                    end
                end
            end
        end
        else begin: gen_ext_ie_64b
            for (i = 0; i < REG_EXT_IE_NUM; i = i + 1) begin: gen_ext_ie
                always @(posedge sys_clk or negedge rst_n) begin
                    if (~rst_n) begin
                        irq_ie_r[(i+1)*DLEN-1:i*DLEN] <= {DLEN{1'b0}};
                    end
                    else begin
                        if (ext_ie_wr && (ext_ie_reg_idx == i[ADDR_DEC_WIDTH-1:0])) begin
                            irq_ie_r[i*DLEN+7:i*DLEN]     <= #UDLY slc_req_mask[0] ? slc_req_data[7:0]   : irq_ie_r[i*DLEN+7:i*DLEN];
                            irq_ie_r[i*DLEN+15:i*DLEN+8]  <= #UDLY slc_req_mask[1] ? slc_req_data[15:8]  : irq_ie_r[i*DLEN+15:i*DLEN+8];
                            irq_ie_r[i*DLEN+23:i*DLEN+16] <= #UDLY slc_req_mask[2] ? slc_req_data[23:16] : irq_ie_r[i*DLEN+23:i*DLEN+16];
                            irq_ie_r[i*DLEN+31:i*DLEN+24] <= #UDLY slc_req_mask[3] ? slc_req_data[31:24] : irq_ie_r[i*DLEN+31:i*DLEN+24];
                            irq_ie_r[i*DLEN+39:i*DLEN+32] <= #UDLY slc_req_mask[4] ? slc_req_data[39:32] : irq_ie_r[i*DLEN+39:i*DLEN+32];
                            irq_ie_r[i*DLEN+47:i*DLEN+40] <= #UDLY slc_req_mask[5] ? slc_req_data[47:40] : irq_ie_r[i*DLEN+47:i*DLEN+40];
                            irq_ie_r[i*DLEN+55:i*DLEN+48] <= #UDLY slc_req_mask[6] ? slc_req_data[55:48] : irq_ie_r[i*DLEN+55:i*DLEN+48];
                            irq_ie_r[i*DLEN+63:i*DLEN+56] <= #UDLY slc_req_mask[7] ? slc_req_data[63:56] : irq_ie_r[i*DLEN+63:i*DLEN+56];
                        end
                    end
                end
            end
        end
    endgenerate

    // Set ext interrupt priority.
    generate
        for (i = 0; i < EXT_IRQ_NUM; i = i + 1) begin: gen_ext_pr
            always @(posedge sys_clk or negedge rst_n) begin
                if (~rst_n) begin
                    irq_pr_r[i] <= {IRQ_PR_WIDTH{1'b0}};
                end
                else begin
                    if (ext_pr_wr && (ext_pr_reg_idx == i[ADDR_DEC_WIDTH-1:0])) begin
                        irq_pr_r[i] <= #UDLY slc_req_mask[0] ? slc_req_data[IRQ_PR_WIDTH-1:0] : irq_pr_r[i];
                    end
                end
            end
        end
    endgenerate

    // Set ext interrupt trigger.
    generate
        for (i = 0; i < EXT_IRQ_NUM; i = i + 1) begin: gen_ext_tg
            always @(posedge sys_clk or negedge rst_n) begin
                if (~rst_n) begin
                    irq_tg_r[i] <= TRIGGER_HILEVEL;
                end
                else begin
                    if (ext_tg_wr && (ext_tg_reg_idx == i[ADDR_DEC_WIDTH-1:0])) begin
                        irq_tg_r[i] <= #UDLY slc_req_mask[0] ? slc_req_data[1:0] : irq_tg_r[i];
                    end
                end
            end
        end
    endgenerate

    // Split IP & IE to 2D matrix.
    generate
        for (i = 0; i < REG_EXT_IP_NUM; i = i + 1) begin: gen_irq_ip_2d
            for (j = 0; j < DLEN; j = j + 1) begin: gen_irq_ip_2d_bit
                if (i * DLEN + j < EXT_IRQ_NUM) begin: gen_irq_ip_2d_bit_vld
                    assign irq_ip_2d[i][j] = irq_ip_r[i * DLEN + j];
                end
                else begin: genirq_ip_2d_bit_pad
                    assign irq_ip_2d[i][j] = 1'b0;
                end
            end
        end
    endgenerate

    generate
        for (i = 0; i < REG_EXT_IE_NUM; i = i + 1) begin: gen_irq_ie_2d
            for (j = 0; j < DLEN; j = j + 1) begin: gen_irq_ie_2d_bit
                if (i * DLEN + j < EXT_IRQ_NUM) begin: gen_irq_ie_2d_bit_vld
                    assign irq_ie_2d[i][j] = irq_ie_r[i * DLEN + j];
                end
                else begin: genirq_ie_2d_bit_pad
                    assign irq_ie_2d[i][j] = 1'b0;
                end
            end
        end
    endgenerate

    // Response buf.
    always @(*) begin
        case (1'b1)
            rst_vec_rd   : rsp_data = {{(DLEN-ALEN){1'b0}}, rst_vec_r};
            sft_irq_rd   : rsp_data = {{(DLEN-1){1'b0}}, sft_irq_r};
            tmr_cfg_rd   : rsp_data = {{(DLEN-32){1'b0}}, tmr_clk_div_r, 14'b0, tmr_auto_clr_r, tmr_cnt_r};
            tmr_val_rd   : rsp_data = tmr_val_r;
            tmr_valh_rd  : rsp_data = tmr_val_r >> 32;
            tmr_cmp_rd   : rsp_data = tmr_cmp_r;
            tmr_cmph_rd  : rsp_data = tmr_cmp_r >> 32;
            sys_icg_rd   : rsp_data = {{(DLEN-32){1'b0}}, sys_icg_r};
            scratch_rd   : rsp_data = {{(DLEN-32){1'b0}}, scratch_r};
            gpio_mode_rd : rsp_data = {{(DLEN-1){1'b0}}, gpio_mode_r};
            irq_claim_rd : rsp_data = {{(DLEN-IRQ_ID_WIDTH){1'b0}}, sel_irq_id_r};
            target_th_rd : rsp_data = {{(DLEN-IRQ_PR_WIDTH){1'b0}}, target_th_r};
            ext_ip_rd    : rsp_data = irq_ip_2d[ext_ip_reg_idx];
            ext_ie_rd    : rsp_data = irq_ie_2d[ext_ie_reg_idx];
            ext_pr_rd    : rsp_data = {{(DLEN-IRQ_PR_WIDTH){1'b0}}, irq_pr_r[ext_pr_reg_idx]};
            ext_tg_rd    : rsp_data = {{(DLEN-2){1'b0}}, irq_tg_r[ext_tg_reg_idx]};
            default      : rsp_data = {DLEN{1'b0}};
        endcase
    end

    always @(posedge sys_clk or negedge rst_n) begin
        if (~rst_n) begin
            rsp_data_r <= {DLEN{1'b0}};
        end
        else begin
            if (slc_req_vld & slc_req_read) begin
                rsp_data_r <= #UDLY rsp_data;
            end
        end
    end

    always @(posedge sys_clk or negedge rst_n) begin
        if (~rst_n) begin
            rsp_vld_r <= 1'b0;
        end
        else begin
            if (slc_req_vld & slc_req_rdy) begin
                rsp_vld_r <= #UDLY 1'b1;
            end
            else if (slc_rsp_vld & slc_rsp_rdy) begin
                rsp_vld_r <= #UDLY 1'b0;
            end
        end
    end
    
    always @(posedge sys_clk or negedge rst_n) begin
        if (~rst_n) begin
            rsp_excp_r <= 1'b0;
        end
        else begin
            if (slc_req_vld & slc_req_rdy & addr_mismatch) begin
                rsp_excp_r <= #UDLY 1'b1;
            end
            else if (slc_rsp_vld & slc_rsp_rdy) begin
                rsp_excp_r <= #UDLY 1'b0;
            end
        end
    end

    // IRQ onehot priority selector.
    uv_arb_fp
    #(
        .WIDTH              ( IRQ_PRI_NUM           )
    )
    u_pri_sel
    (
        .clk                ( sys_clk               ),
        .rst_n              ( rst_n                 ),
        .req                ( irq_pr_com_1hot_rev   ),
        .grant              ( irq_pr_max_1hot_rev   )
    );

    // IRQ arbiter.
    uv_arb_fp
    #(
        .WIDTH              ( EXT_IRQ_NUM           )
    )
    u_irq_arb
    (
        .clk                ( sys_clk               ),
        .rst_n              ( rst_n                 ),
        .req                ( irq_arb_req           ),
        .grant              ( irq_arb_grant         )
    );

endmodule

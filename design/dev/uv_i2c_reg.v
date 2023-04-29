//************************************************************
// See LICENSE for license details.
//
// Module: uv_i2c_reg
//
// Designer: Owen
//
// Description:
//      I2C register access by bus.
//************************************************************

`timescale 1ns / 1ps

module uv_i2c_reg
#(
    parameter ALEN                  = 12,
    parameter DLEN                  = 32,
    parameter MLEN                  = DLEN / 8,
    parameter TXQ_AW                = 3,
    parameter TXQ_DP                = 2**TXQ_AW,
    parameter RXQ_AW                = 3,
    parameter RXQ_DP                = 2**RXQ_AW
)
(
    input                           clk,
    input                           rst_n,

    // APB ports.
    input                           i2c_psel,
    input                           i2c_penable,
    input  [2:0]                    i2c_pprot,
    input  [ALEN-1:0]               i2c_paddr,
    input  [MLEN-1:0]               i2c_pstrb,
    input                           i2c_pwrite,
    input  [DLEN-1:0]               i2c_pwdata,
    output [DLEN-1:0]               i2c_prdata,
    output                          i2c_pready,
    output                          i2c_pslverr,

    // I2C control & status.
    output                          i2c_start,
    input                           i2c_busy,
    input                           i2c_nack,
    input                           i2c_nscl,

    // I2C configs.
    output [7:0]                    nframes,
    output [15:0]                   sda_dly,
    output [15:0]                   clk_div,

    // Queue operations.
    output                          tx_enq_vld,
    output [7:0]                    tx_enq_dat,
    output                          rx_deq_vld,
    input  [7:0]                    rx_deq_dat,

    output                          txq_clr,
    output                          rxq_clr,
    input  [TXQ_AW:0]               txq_len,
    input  [RXQ_AW:0]               rxq_len,
    output                          i2c_irq
);

    localparam UDLY                 = 1;
    localparam ADDR_DEC_WIDTH       = ALEN - 2;

    localparam REG_I2C_GLB_CFG      = 0;
    localparam REG_I2C_NFRAMES      = 1;
    localparam REG_I2C_START        = 2;
    localparam REG_I2C_BUSY         = 3;
    localparam REG_I2C_TXQ_CAP      = 4;
    localparam REG_I2C_TXQ_LEN      = 5;
    localparam REG_I2C_TXQ_CLR      = 6;
    localparam REG_I2C_TXQ_DAT      = 7;
    localparam REG_I2C_RXQ_CAP      = 8;
    localparam REG_I2C_RXQ_LEN      = 9;
    localparam REG_I2C_RXQ_CLR      = 10;
    localparam REG_I2C_RXQ_DAT      = 11;
    localparam REG_I2C_IE           = 12;
    localparam REG_I2C_IP           = 13;
    localparam REG_I2C_TX_IRQ_TH    = 14;
    localparam REG_I2C_RX_IRQ_TH    = 15;
    localparam REG_ADDR_MAX         = 15;

    wire [ADDR_DEC_WIDTH-1:0]       dec_addr;

    reg  [31:0]                     i2c_glb_cfg_r;
    reg  [7:0]                      i2c_nframes_r;
    reg                             i2c_tx_ie_r;
    reg                             i2c_rx_ie_r;
    reg                             i2c_nack_ie_r;
    reg                             i2c_nscl_ie_r;
    wire                            i2c_tx_ip;
    wire                            i2c_rx_ip;
    reg                             i2c_nack_ip_r;
    reg                             i2c_nscl_ip_r;
    reg  [TXQ_AW:0]                 i2c_tx_irq_th_r;
    reg  [RXQ_AW:0]                 i2c_rx_irq_th_r;

    wire                            i2c_glb_cfg_match;
    wire                            i2c_nframes_match;
    wire                            i2c_start_match;
    wire                            i2c_busy_match;
    wire                            i2c_txq_cap_match;
    wire                            i2c_txq_len_match;
    wire                            i2c_txq_clr_match;
    wire                            i2c_txq_dat_match;
    wire                            i2c_rxq_cap_match;
    wire                            i2c_rxq_len_match;
    wire                            i2c_rxq_clr_match;
    wire                            i2c_rxq_dat_match;
    wire                            i2c_ie_match;
    wire                            i2c_ip_match;
    wire                            i2c_tx_irq_th_match;
    wire                            i2c_rx_irq_th_match;
    wire                            addr_mismatch;

    wire                            i2c_glb_cfg_wr;
    wire                            i2c_nframes_wr;
    wire                            i2c_start_wr;
    wire                            i2c_txq_clr_wr;
    wire                            i2c_txq_dat_wr;
    wire                            i2c_rxq_clr_wr;
    wire                            i2c_ie_wr;
    wire                            i2c_tx_irq_th_wr;
    wire                            i2c_rx_irq_th_wr;

    wire                            i2c_glb_cfg_rd;
    wire                            i2c_nframes_rd;
    wire                            i2c_busy_rd;
    wire                            i2c_txq_cap_rd;
    wire                            i2c_txq_len_rd;
    wire                            i2c_rxq_cap_rd;
    wire                            i2c_rxq_len_rd;
    wire                            i2c_rxq_dat_rd;
    wire                            i2c_ie_rd;
    wire                            i2c_ip_rd;
    wire                            i2c_tx_irq_th_rd;
    wire                            i2c_rx_irq_th_rd;

    reg                             rsp_vld_r;
    reg                             rsp_excp_r;
    reg  [DLEN-1:0]                 rsp_data;
    reg  [DLEN-1:0]                 rsp_data_r;

    // Address decoding.
    assign dec_addr                 = i2c_paddr[ALEN-1:2];
    assign i2c_glb_cfg_match        = dec_addr == REG_I2C_GLB_CFG[ADDR_DEC_WIDTH-1:0];
    assign i2c_nframes_match        = dec_addr == REG_I2C_NFRAMES[ADDR_DEC_WIDTH-1:0];
    assign i2c_start_match          = dec_addr == REG_I2C_START  [ADDR_DEC_WIDTH-1:0];
    assign i2c_busy_match           = dec_addr == REG_I2C_BUSY   [ADDR_DEC_WIDTH-1:0];
    assign i2c_txq_cap_match        = dec_addr == REG_I2C_TXQ_CAP[ADDR_DEC_WIDTH-1:0];
    assign i2c_txq_len_match        = dec_addr == REG_I2C_TXQ_LEN[ADDR_DEC_WIDTH-1:0];
    assign i2c_txq_clr_match        = dec_addr == REG_I2C_TXQ_CLR[ADDR_DEC_WIDTH-1:0];
    assign i2c_txq_dat_match        = dec_addr == REG_I2C_TXQ_DAT[ADDR_DEC_WIDTH-1:0];
    assign i2c_rxq_cap_match        = dec_addr == REG_I2C_RXQ_CAP[ADDR_DEC_WIDTH-1:0];
    assign i2c_rxq_len_match        = dec_addr == REG_I2C_RXQ_LEN[ADDR_DEC_WIDTH-1:0];
    assign i2c_rxq_clr_match        = dec_addr == REG_I2C_RXQ_CLR[ADDR_DEC_WIDTH-1:0];
    assign i2c_rxq_dat_match        = dec_addr == REG_I2C_RXQ_DAT[ADDR_DEC_WIDTH-1:0];
    assign i2c_ie_match             = dec_addr == REG_I2C_IE[ADDR_DEC_WIDTH-1:0];
    assign i2c_ip_match             = dec_addr == REG_I2C_IP[ADDR_DEC_WIDTH-1:0];
    assign i2c_tx_irq_th_match      = dec_addr == REG_I2C_TX_IRQ_TH[ADDR_DEC_WIDTH-1:0];
    assign i2c_rx_irq_th_match      = dec_addr == REG_I2C_RX_IRQ_TH[ADDR_DEC_WIDTH-1:0];
    assign addr_mismatch            = dec_addr >  REG_ADDR_MAX[ADDR_DEC_WIDTH-1:0];

    assign i2c_glb_cfg_wr           = i2c_psel & (~i2c_penable) & i2c_pwrite & i2c_glb_cfg_match;
    assign i2c_nframes_wr           = i2c_psel & (~i2c_penable) & i2c_pwrite & i2c_nframes_match;
    assign i2c_start_wr             = i2c_psel & (~i2c_penable) & i2c_pwrite & i2c_start_match;
    assign i2c_txq_clr_wr           = i2c_psel & (~i2c_penable) & i2c_pwrite & i2c_txq_clr_match;
    assign i2c_txq_dat_wr           = i2c_psel & (~i2c_penable) & i2c_pwrite & i2c_txq_dat_match;
    assign i2c_rxq_clr_wr           = i2c_psel & (~i2c_penable) & i2c_pwrite & i2c_txq_clr_match;
    assign i2c_ie_wr                = i2c_psel & (~i2c_penable) & i2c_pwrite & i2c_ie_match;
    assign i2c_ip_wr                = i2c_psel & (~i2c_penable) & i2c_pwrite & i2c_ip_match;
    assign i2c_tx_irq_th_wr         = i2c_psel & (~i2c_penable) & i2c_pwrite & i2c_tx_irq_th_match;
    assign i2c_rx_irq_th_wr         = i2c_psel & (~i2c_penable) & i2c_pwrite & i2c_rx_irq_th_match;

    assign i2c_glb_cfg_rd           = i2c_psel & (~i2c_penable) & (~i2c_pwrite) & i2c_glb_cfg_match;
    assign i2c_nframes_rd           = i2c_psel & (~i2c_penable) & (~i2c_pwrite) & i2c_nframes_match;
    assign i2c_busy_rd              = i2c_psel & (~i2c_penable) & (~i2c_pwrite) & i2c_busy_match;
    assign i2c_txq_cap_rd           = i2c_psel & (~i2c_penable) & (~i2c_pwrite) & i2c_txq_cap_match;
    assign i2c_txq_len_rd           = i2c_psel & (~i2c_penable) & (~i2c_pwrite) & i2c_txq_len_match;
    assign i2c_rxq_cap_rd           = i2c_psel & (~i2c_penable) & (~i2c_pwrite) & i2c_rxq_cap_match;
    assign i2c_rxq_len_rd           = i2c_psel & (~i2c_penable) & (~i2c_pwrite) & i2c_rxq_len_match;
    assign i2c_rxq_dat_rd           = i2c_psel & (~i2c_penable) & (~i2c_pwrite) & i2c_rxq_dat_match;
    assign i2c_ie_rd                = i2c_psel & (~i2c_penable) & (~i2c_pwrite) & i2c_ie_match;
    assign i2c_ip_rd                = i2c_psel & (~i2c_penable) & (~i2c_pwrite) & i2c_ip_match;
    assign i2c_tx_irq_th_rd         = i2c_psel & (~i2c_penable) & (~i2c_pwrite) & i2c_tx_irq_th_match;
    assign i2c_rx_irq_th_rd         = i2c_psel & (~i2c_penable) & (~i2c_pwrite) & i2c_rx_irq_th_match;

    // Bus response.
    assign i2c_prdata               = rsp_data_r;
    assign i2c_pready               = rsp_vld_r;
    assign i2c_pslverr              = rsp_excp_r;

    // Output configs.
    assign sda_dly                  = i2c_glb_cfg_r[15:0];
    assign clk_div                  = i2c_glb_cfg_r[31:16];
    assign nframes                  = i2c_nframes_r;

    assign i2c_start                = i2c_start_wr;

    assign txq_clr                  = i2c_txq_clr_wr;
    assign rxq_clr                  = i2c_rxq_clr_wr;

    // Output data.
    assign tx_enq_vld               = i2c_txq_dat_wr;
    assign tx_enq_dat               = i2c_pwdata[7:0];
    assign rx_deq_vld               = i2c_rxq_dat_rd;

    // Interrupt.
    assign i2c_tx_ip                = txq_len <= i2c_tx_irq_th_r;
    assign i2c_rx_ip                = rxq_len >= i2c_rx_irq_th_r;
    assign i2c_irq                  = (i2c_rx_ip & i2c_rx_ie_r)
                                    | (i2c_tx_ip & i2c_tx_ie_r)
                                    | (i2c_nack_ip_r & i2c_nack_ie_r)
                                    | (i2c_nscl_ip_r & i2c_nscl_ie_r);

    // Write registers from bus.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            i2c_glb_cfg_r <= 32'b0;
        end
        else begin
            if (i2c_glb_cfg_wr) begin
                i2c_glb_cfg_r[7:0]   <= #UDLY i2c_pstrb[0] ? i2c_pwdata[7:0]   : i2c_glb_cfg_r[7:0];
                i2c_glb_cfg_r[15:8]  <= #UDLY i2c_pstrb[1] ? i2c_pwdata[15:8]  : i2c_glb_cfg_r[15:8];
                i2c_glb_cfg_r[23:16] <= #UDLY i2c_pstrb[2] ? i2c_pwdata[23:16] : i2c_glb_cfg_r[23:16];
                i2c_glb_cfg_r[31:24] <= #UDLY i2c_pstrb[3] ? i2c_pwdata[31:24] : i2c_glb_cfg_r[31:24];
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            i2c_nframes_r <= 8'b0;
        end
        else begin
            if (i2c_nframes_wr) begin
                i2c_nframes_r[7:0]  <= #UDLY i2c_pstrb[0] ? i2c_pwdata[7:0] : i2c_nframes_r[7:0];
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            i2c_tx_ie_r   <= 1'b0;
            i2c_rx_ie_r   <= 1'b0;
            i2c_nack_ie_r <= 1'b0;
            i2c_nscl_ie_r <= 1'b0;
        end
        else begin
            if (i2c_ie_wr) begin
                i2c_tx_ie_r   <= #UDLY i2c_pstrb[0] ? i2c_pwdata[0] : i2c_tx_ie_r;
                i2c_rx_ie_r   <= #UDLY i2c_pstrb[0] ? i2c_pwdata[1] : i2c_rx_ie_r;
                i2c_nack_ie_r <= #UDLY i2c_pstrb[0] ? i2c_pwdata[2] : i2c_nack_ie_r;
                i2c_nscl_ie_r <= #UDLY i2c_pstrb[0] ? i2c_pwdata[3] : i2c_nscl_ie_r;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            i2c_nack_ip_r <= 1'b0;
        end
        else begin
            if (i2c_nack) begin
                i2c_nack_ip_r <= #UDLY 1'b1;
            end
            else if (i2c_ip_wr) begin
                i2c_nack_ip_r <= #UDLY i2c_pstrb[0] ? i2c_pwdata[2] : i2c_nack_ip_r;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            i2c_nscl_ip_r <= 1'b0;
        end
        else begin
            if (i2c_nscl) begin
                i2c_nscl_ip_r <= #UDLY 1'b1;
            end
            else if (i2c_ip_wr) begin
                i2c_nscl_ip_r <= #UDLY i2c_pstrb[0] ? i2c_pwdata[3] : i2c_nscl_ip_r;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            i2c_tx_irq_th_r <= {(TXQ_AW+1){1'b0}};
        end
        else begin
            if (i2c_tx_irq_th_wr) begin
                i2c_tx_irq_th_r <= #UDLY i2c_pstrb[0] ? i2c_pwdata[TXQ_AW:0] : i2c_tx_irq_th_r;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            i2c_rx_irq_th_r <= {(RXQ_AW+1){1'b0}};
        end
        else begin
            if (i2c_rx_irq_th_wr) begin
                i2c_rx_irq_th_r <= #UDLY i2c_pstrb[0] ? i2c_pwdata[RXQ_AW:0] : i2c_rx_irq_th_r;
            end
        end
    end

    // Buffer bus response.
    always @(*) begin
        case (1'b1)
            i2c_glb_cfg_rd   : rsp_data = {{(DLEN-32){1'b0}}, i2c_glb_cfg_r};
            i2c_nframes_rd   : rsp_data = {{(DLEN-8){1'b0}}, i2c_nframes_r};
            i2c_busy_rd      : rsp_data = {{(DLEN-1){1'b0}}, i2c_busy};
            i2c_txq_cap_rd   : rsp_data = TXQ_DP[DLEN-1:0];
            i2c_txq_len_rd   : rsp_data = {{(DLEN-TXQ_AW-1){1'b0}}, txq_len};
            i2c_rxq_cap_rd   : rsp_data = RXQ_DP[DLEN-1:0];
            i2c_rxq_len_rd   : rsp_data = {{(DLEN-RXQ_AW-1){1'b0}}, rxq_len};
            i2c_rxq_dat_rd   : rsp_data = {{(DLEN-32){1'b0}}, rx_deq_dat};
            i2c_ie_rd        : rsp_data = {{(DLEN-4){1'b0}}, i2c_nscl_ie_r, i2c_nack_ie_r, i2c_rx_ie_r, i2c_tx_ie_r};
            i2c_ip_rd        : rsp_data = {{(DLEN-4){1'b0}}, i2c_nscl_ip_r, i2c_nack_ip_r, i2c_rx_ip, i2c_tx_ip};
            i2c_tx_irq_th_rd : rsp_data = {{(DLEN-TXQ_AW-1){1'b0}}, i2c_tx_irq_th_r};
            i2c_rx_irq_th_rd : rsp_data = {{(DLEN-TXQ_AW-1){1'b0}}, i2c_rx_irq_th_r};
            default          : rsp_data = {DLEN{1'b0}};
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rsp_data_r <= {DLEN{1'b0}};
        end
        else begin
            if (i2c_psel & (~i2c_penable)) begin
                rsp_data_r <= #UDLY rsp_data;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rsp_vld_r <= 1'b0;
        end
        else begin
            if (i2c_psel & (~i2c_penable)) begin
                rsp_vld_r <= #UDLY 1'b1;
            end
            else begin
                rsp_vld_r <= #UDLY 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rsp_excp_r <= 1'b0;
        end
        else begin
            if (i2c_psel & (~i2c_penable) & addr_mismatch) begin
                rsp_excp_r <= #UDLY 1'b1;
            end
            else begin
                rsp_excp_r <= #UDLY 1'b0;
            end
        end
    end

endmodule

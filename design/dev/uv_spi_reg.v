//************************************************************
// See LICENSE for license details.
//
// Module: uv_spi_reg
//
// Designer: Owen
//
// Description:
//      SPI register access by bus.
//************************************************************

`timescale 1ns / 1ps

module uv_spi_reg
#(
    parameter ALEN                  = 12,
    parameter DLEN                  = 32,
    parameter MLEN                  = DLEN / 8,
    parameter TXQ_AW                = 3,
    parameter TXQ_DP                = 2**TXQ_AW,
    parameter RXQ_AW                = 3,
    parameter RXQ_DP                = 2**RXQ_AW,
    parameter CS_NUM                = 4
)
(
    input                           clk,
    input                           rst_n,

    // APB ports.
    input                           spi_psel,
    input                           spi_penable,
    input  [2:0]                    spi_pprot,
    input  [ALEN-1:0]               spi_paddr,
    input  [MLEN-1:0]               spi_pstrb,
    input                           spi_pwrite,
    input  [DLEN-1:0]               spi_pwdata,
    output [DLEN-1:0]               spi_prdata,
    output                          spi_pready,
    output                          spi_pslverr,

    // SPI control & status.
    output [CS_NUM-1:0]             def_idle,
    output [CS_NUM-1:0]             spi_mask,
    output                          spi_cpol,
    output                          spi_cpha,
    output                          spi_rxen,
    output [4:0]                    spi_unit,
    output [7:0]                    sck_dly,
    output [15:0]                   clk_div,
    output                          spi_irq,
    output                          endian,

    output                          tx_enq_vld,
    output [31:0]                   tx_enq_dat,
    output                          rx_deq_vld,
    input  [31:0]                   rx_deq_dat,

    output                          txq_clr,
    output                          rxq_clr,
    input  [TXQ_AW:0]               txq_len,
    input  [RXQ_AW:0]               rxq_len
);

    localparam UDLY                 = 1;
    localparam ADDR_DEC_WIDTH       = ALEN - 2;

    localparam REG_SPI_GLB_CFG      = 0;
    localparam REG_SPI_RECV_EN      = 1;
    localparam REG_SPI_CS_IDLE      = 2;
    localparam REG_SPI_CS_MASK      = 3;
    localparam REG_SPI_TXQ_CAP      = 4;
    localparam REG_SPI_TXQ_LEN      = 5;
    localparam REG_SPI_TXQ_CLR      = 6;
    localparam REG_SPI_TXQ_DAT      = 7;
    localparam REG_SPI_RXQ_CAP      = 8;
    localparam REG_SPI_RXQ_LEN      = 9;
    localparam REG_SPI_RXQ_CLR      = 10;
    localparam REG_SPI_RXQ_DAT      = 11;
    localparam REG_SPI_IE           = 12;
    localparam REG_SPI_IP           = 13;
    localparam REG_SPI_TX_IRQ_TH    = 14;
    localparam REG_SPI_RX_IRQ_TH    = 15;
    localparam REG_ADDR_MAX         = 15;

    wire [ADDR_DEC_WIDTH-1:0]       dec_addr;

    reg  [31:0]                     spi_glb_cfg_r;
    reg                             spi_recv_en_r;
    reg  [CS_NUM-1:0]               spi_cs_idle_r;
    reg  [CS_NUM-1:0]               spi_cs_mask_r;
    reg                             spi_tx_ie_r;
    reg                             spi_rx_ie_r;
    wire                            spi_tx_ip;
    wire                            spi_rx_ip;
    reg  [TXQ_AW:0]                 spi_tx_irq_th_r;
    reg  [RXQ_AW:0]                 spi_rx_irq_th_r;

    wire                            spi_glb_cfg_match;
    wire                            spi_recv_en_match;
    wire                            spi_cs_idle_match;
    wire                            spi_cs_mask_match;
    wire                            spi_txq_cap_match;
    wire                            spi_txq_len_match;
    wire                            spi_txq_clr_match;
    wire                            spi_txq_dat_match;
    wire                            spi_rxq_cap_match;
    wire                            spi_rxq_len_match;
    wire                            spi_rxq_clr_match;
    wire                            spi_rxq_dat_match;
    wire                            spi_ie_match;
    wire                            spi_ip_match;
    wire                            spi_tx_irq_th_match;
    wire                            spi_rx_irq_th_match;
    wire                            addr_mismatch;

    wire                            spi_glb_cfg_wr;
    wire                            spi_recv_en_wr;
    wire                            spi_cs_idle_wr;
    wire                            spi_cs_mask_wr;
    wire                            spi_txq_clr_wr;
    wire                            spi_txq_dat_wr;
    wire                            spi_rxq_clr_wr;
    wire                            spi_ie_wr;
    wire                            spi_tx_irq_th_wr;
    wire                            spi_rx_irq_th_wr;

    wire                            spi_glb_cfg_rd;
    wire                            spi_recv_en_rd;
    wire                            spi_cs_idle_rd;
    wire                            spi_cs_mask_rd;
    wire                            spi_txq_cap_rd;
    wire                            spi_txq_len_rd;
    wire                            spi_rxq_cap_rd;
    wire                            spi_rxq_len_rd;
    wire                            spi_rxq_dat_rd;
    wire                            spi_ie_rd;
    wire                            spi_ip_rd;
    wire                            spi_tx_irq_th_rd;
    wire                            spi_rx_irq_th_rd;

    reg                             rsp_vld_r;
    reg                             rsp_excp_r;
    reg  [DLEN-1:0]                 rsp_data;
    reg  [DLEN-1:0]                 rsp_data_r;

    // Address decoding.
    assign dec_addr                 = spi_paddr[ALEN-1:2];
    assign spi_glb_cfg_match        = dec_addr == REG_SPI_GLB_CFG[ADDR_DEC_WIDTH-1:0];
    assign spi_recv_en_match        = dec_addr == REG_SPI_RECV_EN[ADDR_DEC_WIDTH-1:0];
    assign spi_cs_idle_match        = dec_addr == REG_SPI_CS_IDLE[ADDR_DEC_WIDTH-1:0];
    assign spi_cs_mask_match        = dec_addr == REG_SPI_CS_MASK[ADDR_DEC_WIDTH-1:0];
    assign spi_txq_cap_match        = dec_addr == REG_SPI_TXQ_CAP[ADDR_DEC_WIDTH-1:0];
    assign spi_txq_len_match        = dec_addr == REG_SPI_TXQ_LEN[ADDR_DEC_WIDTH-1:0];
    assign spi_txq_clr_match        = dec_addr == REG_SPI_TXQ_CLR[ADDR_DEC_WIDTH-1:0];
    assign spi_txq_dat_match        = dec_addr == REG_SPI_TXQ_DAT[ADDR_DEC_WIDTH-1:0];
    assign spi_rxq_cap_match        = dec_addr == REG_SPI_RXQ_CAP[ADDR_DEC_WIDTH-1:0];
    assign spi_rxq_len_match        = dec_addr == REG_SPI_RXQ_LEN[ADDR_DEC_WIDTH-1:0];
    assign spi_rxq_clr_match        = dec_addr == REG_SPI_RXQ_CLR[ADDR_DEC_WIDTH-1:0];
    assign spi_rxq_dat_match        = dec_addr == REG_SPI_RXQ_DAT[ADDR_DEC_WIDTH-1:0];
    assign spi_ie_match             = dec_addr == REG_SPI_IE[ADDR_DEC_WIDTH-1:0];
    assign spi_ip_match             = dec_addr == REG_SPI_IP[ADDR_DEC_WIDTH-1:0];
    assign spi_tx_irq_th_match      = dec_addr == REG_SPI_TX_IRQ_TH[ADDR_DEC_WIDTH-1:0];
    assign spi_rx_irq_th_match      = dec_addr == REG_SPI_RX_IRQ_TH[ADDR_DEC_WIDTH-1:0];
    assign addr_mismatch            = dec_addr >  REG_ADDR_MAX[ADDR_DEC_WIDTH-1:0];

    assign spi_glb_cfg_wr           = spi_psel & (~spi_penable) & spi_pwrite & spi_glb_cfg_match;
    assign spi_recv_en_wr           = spi_psel & (~spi_penable) & spi_pwrite & spi_recv_en_match;
    assign spi_cs_idle_wr           = spi_psel & (~spi_penable) & spi_pwrite & spi_cs_idle_match;
    assign spi_cs_mask_wr           = spi_psel & (~spi_penable) & spi_pwrite & spi_cs_mask_match;
    assign spi_txq_clr_wr           = spi_psel & (~spi_penable) & spi_pwrite & spi_txq_clr_match;
    assign spi_txq_dat_wr           = spi_psel & (~spi_penable) & spi_pwrite & spi_txq_dat_match;
    assign spi_rxq_clr_wr           = spi_psel & (~spi_penable) & spi_pwrite & spi_txq_clr_match;
    assign spi_ie_wr                = spi_psel & (~spi_penable) & spi_pwrite & spi_ie_match;
    assign spi_tx_irq_th_wr         = spi_psel & (~spi_penable) & spi_pwrite & spi_tx_irq_th_match;
    assign spi_rx_irq_th_wr         = spi_psel & (~spi_penable) & spi_pwrite & spi_rx_irq_th_match;

    assign spi_glb_cfg_rd           = spi_psel & (~spi_penable) & (~spi_pwrite) & spi_glb_cfg_match;
    assign spi_recv_en_rd           = spi_psel & (~spi_penable) & (~spi_pwrite) & spi_recv_en_match;
    assign spi_cs_idle_rd           = spi_psel & (~spi_penable) & (~spi_pwrite) & spi_cs_idle_match;
    assign spi_cs_mask_rd           = spi_psel & (~spi_penable) & (~spi_pwrite) & spi_cs_mask_match;
    assign spi_txq_cap_rd           = spi_psel & (~spi_penable) & (~spi_pwrite) & spi_txq_cap_match;
    assign spi_txq_len_rd           = spi_psel & (~spi_penable) & (~spi_pwrite) & spi_txq_len_match;
    assign spi_rxq_cap_rd           = spi_psel & (~spi_penable) & (~spi_pwrite) & spi_rxq_cap_match;
    assign spi_rxq_len_rd           = spi_psel & (~spi_penable) & (~spi_pwrite) & spi_rxq_len_match;
    assign spi_rxq_dat_rd           = spi_psel & (~spi_penable) & (~spi_pwrite) & spi_rxq_dat_match;
    assign spi_ie_rd                = spi_psel & (~spi_penable) & (~spi_pwrite) & spi_ie_match;
    assign spi_ip_rd                = spi_psel & (~spi_penable) & (~spi_pwrite) & spi_ip_match;
    assign spi_tx_irq_th_rd         = spi_psel & (~spi_penable) & (~spi_pwrite) & spi_tx_irq_th_match;
    assign spi_rx_irq_th_rd         = spi_psel & (~spi_penable) & (~spi_pwrite) & spi_rx_irq_th_match;

    // Bus response.
    assign spi_prdata               = rsp_data_r;
    assign spi_pready               = rsp_vld_r;
    assign spi_pslverr              = rsp_excp_r;

    // Output configs.
    assign spi_cpol                 = spi_glb_cfg_r[0];
    assign spi_cpha                 = spi_glb_cfg_r[1];
    assign endian                   = spi_glb_cfg_r[2];
    assign spi_unit                 = spi_glb_cfg_r[7:3];
    assign sck_dly                  = spi_glb_cfg_r[15:8];
    assign clk_div                  = spi_glb_cfg_r[31:16];

    assign spi_rxen                 = spi_recv_en_r;
    assign def_idle                 = spi_cs_idle_r;
    assign spi_mask                 = spi_cs_mask_r;

    assign txq_clr                  = spi_txq_clr_wr;
    assign rxq_clr                  = spi_rxq_clr_wr;

    // Output data.
    assign tx_enq_vld               = spi_txq_dat_wr;
    assign tx_enq_dat               = spi_pwdata[31:0];
    assign rx_deq_vld               = spi_rxq_dat_rd;

    // Interrupt.
    assign spi_tx_ip                = txq_len <= spi_tx_irq_th_r;
    assign spi_rx_ip                = rxq_len >= spi_rx_irq_th_r;
    assign spi_irq                  = (spi_rx_ip & spi_rx_ie_r) | (spi_tx_ip & spi_tx_ie_r);

    // Write registers from bus.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            spi_glb_cfg_r <= 32'b0;
        end
        else begin
            if (spi_glb_cfg_wr) begin
                spi_glb_cfg_r[7:0]   <= #UDLY spi_pstrb[0] ? spi_pwdata[7:0]   : spi_glb_cfg_r[7:0];
                spi_glb_cfg_r[15:8]  <= #UDLY spi_pstrb[1] ? spi_pwdata[15:8]  : spi_glb_cfg_r[15:8];
                spi_glb_cfg_r[23:16] <= #UDLY spi_pstrb[2] ? spi_pwdata[23:16] : spi_glb_cfg_r[23:16];
                spi_glb_cfg_r[31:24] <= #UDLY spi_pstrb[3] ? spi_pwdata[31:24] : spi_glb_cfg_r[31:24];
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            spi_recv_en_r <= 1'b0;
        end
        else begin
            if (spi_recv_en_wr) begin
                spi_recv_en_r <= #UDLY spi_pstrb[0] ? spi_pwdata[0] : spi_recv_en_r;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            spi_cs_idle_r <= {CS_NUM{1'b1}};
        end
        else begin
            if (spi_cs_idle_wr) begin
                spi_cs_idle_r <= #UDLY spi_pstrb[0] ? spi_pwdata[CS_NUM-1:0] : spi_cs_idle_r;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            spi_cs_mask_r <= {CS_NUM{1'b0}};
        end
        else begin
            if (spi_cs_mask_wr) begin
                spi_cs_mask_r <= #UDLY spi_pstrb[0] ? spi_pwdata[CS_NUM-1:0] : spi_cs_mask_r;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            spi_tx_ie_r <= 1'b0;
            spi_rx_ie_r <= 1'b0;
        end
        else begin
            if (spi_ie_wr) begin
                spi_tx_ie_r <= #UDLY spi_pstrb[0] ? spi_pwdata[0] : spi_tx_ie_r;
                spi_rx_ie_r <= #UDLY spi_pstrb[0] ? spi_pwdata[1] : spi_rx_ie_r;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            spi_tx_irq_th_r <= {(TXQ_AW+1){1'b0}};
        end
        else begin
            if (spi_tx_irq_th_wr) begin
                spi_tx_irq_th_r <= #UDLY spi_pstrb[0] ? spi_pwdata[TXQ_AW:0] : spi_tx_irq_th_r;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            spi_rx_irq_th_r <= {(RXQ_AW+1){1'b0}};
        end
        else begin
            if (spi_rx_irq_th_wr) begin
                spi_rx_irq_th_r <= #UDLY spi_pstrb[0] ? spi_pwdata[RXQ_AW:0] : spi_rx_irq_th_r;
            end
        end
    end

    // Buffer bus response.
    always @(*) begin
        case (1'b1)
            spi_glb_cfg_rd   : rsp_data = {{(DLEN-32){1'b0}}, spi_glb_cfg_r};
            spi_recv_en_rd   : rsp_data = {{(DLEN-1){1'b0}}, spi_recv_en_r};
            spi_cs_idle_rd   : rsp_data = {{(DLEN-CS_NUM){1'b0}}, spi_cs_idle_r};
            spi_cs_mask_rd   : rsp_data = {{(DLEN-CS_NUM){1'b0}}, spi_cs_mask_r};
            spi_txq_cap_rd   : rsp_data = TXQ_DP[DLEN-1:0];
            spi_txq_len_rd   : rsp_data = {{(DLEN-TXQ_AW-1){1'b0}}, txq_len};
            spi_rxq_cap_rd   : rsp_data = RXQ_DP[DLEN-1:0];
            spi_rxq_len_rd   : rsp_data = {{(DLEN-RXQ_AW-1){1'b0}}, rxq_len};
            spi_rxq_dat_rd   : rsp_data = {{(DLEN-32){1'b0}}, rx_deq_dat};
            spi_ie_rd        : rsp_data = {{(DLEN-2){1'b0}}, spi_rx_ie_r, spi_tx_ie_r};
            spi_ip_rd        : rsp_data = {{(DLEN-2){1'b0}}, spi_rx_ip, spi_tx_ip};
            spi_tx_irq_th_rd : rsp_data = {{(DLEN-TXQ_AW-1){1'b0}}, spi_tx_irq_th_r};
            spi_rx_irq_th_rd : rsp_data = {{(DLEN-TXQ_AW-1){1'b0}}, spi_rx_irq_th_r};
            default          : rsp_data = {DLEN{1'b0}};
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rsp_data_r <= {DLEN{1'b0}};
        end
        else begin
            if (spi_psel & (~spi_penable)) begin
                rsp_data_r <= #UDLY rsp_data;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rsp_vld_r <= 1'b0;
        end
        else begin
            if (spi_psel & (~spi_penable)) begin
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
            if (spi_psel & (~spi_penable) & addr_mismatch) begin
                rsp_excp_r <= #UDLY 1'b1;
            end
            else begin
                rsp_excp_r <= #UDLY 1'b0;
            end
        end
    end

endmodule

//************************************************************
// See LICENSE for license details.
//
// Module: uv_uart_reg
//
// Designer: Owen
//
// Description:
//      UART register access by bus.
//************************************************************

`timescale 1ns / 1ps

module uv_uart_reg
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
    input                           uart_psel,
    input                           uart_penable,
    input  [2:0]                    uart_pprot,
    input  [ALEN-1:0]               uart_paddr,
    input  [MLEN-1:0]               uart_pstrb,
    input                           uart_pwrite,
    input  [DLEN-1:0]               uart_pwdata,
    output [DLEN-1:0]               uart_prdata,
    output                          uart_pready,
    output                          uart_pslverr,

    // UART control & status.
    output                          tx_en,
    output                          rx_en,
    output [1:0]                    nbits,
    output                          nstop,
    output                          endian,
    output [15:0]                   clk_div,
    output                          parity_en,
    output [1:0]                    parity_type,
    output                          uart_irq,

    output                          tx_enq_vld,
    output [7:0]                    tx_enq_dat,
    output                          rx_deq_vld,
    input  [7:0]                    rx_deq_dat,

    output                          txq_clr,
    output                          rxq_clr,
    input  [TXQ_AW:0]               txq_len,
    input  [RXQ_AW:0]               rxq_len
);

    localparam UDLY                 = 1;
    localparam ADDR_DEC_WIDTH       = ALEN - 2;

    localparam REG_UART_GLB_CFG     = 0;
    localparam REG_UART_TXQ_CAP     = 1;
    localparam REG_UART_TXQ_LEN     = 2;
    localparam REG_UART_TXQ_CLR     = 3;
    localparam REG_UART_TXQ_DAT     = 4;
    localparam REG_UART_RXQ_CAP     = 5;
    localparam REG_UART_RXQ_LEN     = 6;
    localparam REG_UART_RXQ_CLR     = 7;
    localparam REG_UART_RXQ_DAT     = 8;
    localparam REG_UART_IE          = 9;
    localparam REG_UART_IP          = 10;
    localparam REG_UART_TX_IRQ_TH   = 11;
    localparam REG_UART_RX_IRQ_TH   = 12;
    localparam REG_ADDR_MAX         = 12;

    wire [ADDR_DEC_WIDTH-1:0]       dec_addr;

    reg  [31:0]                     uart_glb_cfg_r;
    reg                             uart_tx_ie_r;
    reg                             uart_rx_ie_r;
    wire                            uart_tx_ip;
    wire                            uart_rx_ip;
    reg  [TXQ_AW:0]                 uart_tx_irq_th_r;
    reg  [RXQ_AW:0]                 uart_rx_irq_th_r;

    wire                            uart_glb_cfg_match;
    wire                            uart_txq_cap_match;
    wire                            uart_txq_len_match;
    wire                            uart_txq_clr_match;
    wire                            uart_txq_dat_match;
    wire                            uart_rxq_cap_match;
    wire                            uart_rxq_len_match;
    wire                            uart_rxq_clr_match;
    wire                            uart_rxq_dat_match;
    wire                            uart_ie_match;
    wire                            uart_ip_match;
    wire                            uart_tx_irq_th_match;
    wire                            uart_rx_irq_th_match;
    wire                            addr_mismatch;

    wire                            uart_glb_cfg_wr;
    wire                            uart_txq_clr_wr;
    wire                            uart_txq_dat_wr;
    wire                            uart_rxq_clr_wr;
    wire                            uart_ie_wr;
    wire                            uart_tx_irq_th_wr;
    wire                            uart_rx_irq_th_wr;

    wire                            uart_glb_cfg_rd;
    wire                            uart_txq_cap_rd;
    wire                            uart_txq_len_rd;
    wire                            uart_rxq_cap_rd;
    wire                            uart_rxq_len_rd;
    wire                            uart_rxq_dat_rd;
    wire                            uart_ie_rd;
    wire                            uart_ip_rd;
    wire                            uart_tx_irq_th_rd;
    wire                            uart_rx_irq_th_rd;

    reg                             rsp_vld_r;
    reg                             rsp_excp_r;
    reg  [DLEN-1:0]                 rsp_data;
    reg  [DLEN-1:0]                 rsp_data_r;

    // Address decoding.
    assign dec_addr                 = uart_paddr[ALEN-1:2];
    assign uart_glb_cfg_match       = dec_addr == REG_UART_GLB_CFG[ADDR_DEC_WIDTH-1:0];
    assign uart_txq_cap_match       = dec_addr == REG_UART_TXQ_CAP[ADDR_DEC_WIDTH-1:0];
    assign uart_txq_len_match       = dec_addr == REG_UART_TXQ_LEN[ADDR_DEC_WIDTH-1:0];
    assign uart_txq_clr_match       = dec_addr == REG_UART_TXQ_CLR[ADDR_DEC_WIDTH-1:0];
    assign uart_txq_dat_match       = dec_addr == REG_UART_TXQ_DAT[ADDR_DEC_WIDTH-1:0];
    assign uart_rxq_cap_match       = dec_addr == REG_UART_RXQ_CAP[ADDR_DEC_WIDTH-1:0];
    assign uart_rxq_len_match       = dec_addr == REG_UART_RXQ_LEN[ADDR_DEC_WIDTH-1:0];
    assign uart_rxq_clr_match       = dec_addr == REG_UART_RXQ_CLR[ADDR_DEC_WIDTH-1:0];
    assign uart_rxq_dat_match       = dec_addr == REG_UART_RXQ_DAT[ADDR_DEC_WIDTH-1:0];
    assign uart_ie_match            = dec_addr == REG_UART_IE[ADDR_DEC_WIDTH-1:0];
    assign uart_ip_match            = dec_addr == REG_UART_IP[ADDR_DEC_WIDTH-1:0];
    assign uart_tx_irq_th_match     = dec_addr == REG_UART_TX_IRQ_TH[ADDR_DEC_WIDTH-1:0];
    assign uart_rx_irq_th_match     = dec_addr == REG_UART_RX_IRQ_TH[ADDR_DEC_WIDTH-1:0];
    assign addr_mismatch            = dec_addr >  REG_ADDR_MAX[ADDR_DEC_WIDTH-1:0];

    assign uart_glb_cfg_wr          = uart_psel & (~uart_penable) & uart_pwrite & uart_glb_cfg_match;
    assign uart_txq_clr_wr          = uart_psel & (~uart_penable) & uart_pwrite & uart_txq_clr_match;
    assign uart_txq_dat_wr          = uart_psel & (~uart_penable) & uart_pwrite & uart_txq_dat_match;
    assign uart_rxq_clr_wr          = uart_psel & (~uart_penable) & uart_pwrite & uart_txq_clr_match;
    assign uart_ie_wr               = uart_psel & (~uart_penable) & uart_pwrite & uart_ie_match;
    assign uart_tx_irq_th_wr        = uart_psel & (~uart_penable) & uart_pwrite & uart_tx_irq_th_match;
    assign uart_rx_irq_th_wr        = uart_psel & (~uart_penable) & uart_pwrite & uart_rx_irq_th_match;

    assign uart_glb_cfg_rd          = uart_psel & (~uart_penable) & (~uart_pwrite) & uart_glb_cfg_match;
    assign uart_txq_cap_rd          = uart_psel & (~uart_penable) & (~uart_pwrite) & uart_txq_cap_match;
    assign uart_txq_len_rd          = uart_psel & (~uart_penable) & (~uart_pwrite) & uart_txq_len_match;
    assign uart_rxq_cap_rd          = uart_psel & (~uart_penable) & (~uart_pwrite) & uart_rxq_cap_match;
    assign uart_rxq_len_rd          = uart_psel & (~uart_penable) & (~uart_pwrite) & uart_rxq_len_match;
    assign uart_rxq_dat_rd          = uart_psel & (~uart_penable) & (~uart_pwrite) & uart_rxq_dat_match;
    assign uart_ie_rd               = uart_psel & (~uart_penable) & (~uart_pwrite) & uart_ie_match;
    assign uart_ip_rd               = uart_psel & (~uart_penable) & (~uart_pwrite) & uart_ip_match;
    assign uart_tx_irq_th_rd        = uart_psel & (~uart_penable) & (~uart_pwrite) & uart_tx_irq_th_match;
    assign uart_rx_irq_th_rd        = uart_psel & (~uart_penable) & (~uart_pwrite) & uart_rx_irq_th_match;

    // Bus response.
    assign uart_prdata              = rsp_data_r;
    assign uart_pready              = rsp_vld_r;
    assign uart_pslverr             = rsp_excp_r;

    // Output configs.
    assign tx_en                    = uart_glb_cfg_r[0];
    assign rx_en                    = uart_glb_cfg_r[1];
    assign nbits                    = uart_glb_cfg_r[3:2];
    assign nstop                    = uart_glb_cfg_r[4];
    assign endian                   = uart_glb_cfg_r[5];
    assign parity_en                = uart_glb_cfg_r[7];
    assign parity_type              = uart_glb_cfg_r[9:8];
    assign clk_div                  = uart_glb_cfg_r[31:16];

    assign txq_clr                  = uart_txq_clr_wr;
    assign rxq_clr                  = uart_rxq_clr_wr;

    // Output data.
    assign tx_enq_vld               = uart_txq_dat_wr;
    assign tx_enq_dat               = uart_pwdata[7:0];
    assign rx_deq_vld               = uart_rxq_dat_rd;

    // Interrupt.
    assign uart_tx_ip               = txq_len <= uart_tx_irq_th_r;
    assign uart_rx_ip               = rxq_len >= uart_rx_irq_th_r;
    assign uart_irq                 = (uart_rx_ip & uart_rx_ie_r) | (uart_tx_ip & uart_tx_ie_r);

    // Write registers from bus.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            uart_glb_cfg_r <= 32'b0;
        end
        else begin
            if (uart_glb_cfg_wr) begin
                uart_glb_cfg_r[7:0]   <= #UDLY uart_pstrb[0] ? uart_pwdata[7:0]   : uart_glb_cfg_r[7:0];
                uart_glb_cfg_r[15:8]  <= #UDLY uart_pstrb[1] ? uart_pwdata[15:8]  : uart_glb_cfg_r[15:8];
                uart_glb_cfg_r[23:16] <= #UDLY uart_pstrb[2] ? uart_pwdata[23:16] : uart_glb_cfg_r[23:16];
                uart_glb_cfg_r[31:24] <= #UDLY uart_pstrb[3] ? uart_pwdata[31:24] : uart_glb_cfg_r[31:24];
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            uart_tx_ie_r <= 1'b0;
            uart_rx_ie_r <= 1'b0;
        end
        else begin
            if (uart_ie_wr) begin
                uart_tx_ie_r <= #UDLY uart_pstrb[0] ? uart_pwdata[0] : uart_tx_ie_r;
                uart_rx_ie_r <= #UDLY uart_pstrb[0] ? uart_pwdata[1] : uart_rx_ie_r;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            uart_tx_irq_th_r <= {(TXQ_AW+1){1'b0}};
        end
        else begin
            if (uart_tx_irq_th_wr) begin
                uart_tx_irq_th_r <= #UDLY uart_pstrb[0] ? uart_pwdata[TXQ_AW:0] : uart_tx_irq_th_r;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            uart_rx_irq_th_r <= {(RXQ_AW+1){1'b0}};
        end
        else begin
            if (uart_rx_irq_th_wr) begin
                uart_rx_irq_th_r <= #UDLY uart_pstrb[0] ? uart_pwdata[RXQ_AW:0] : uart_rx_irq_th_r;
            end
        end
    end

    // Buffer bus response.
    always @(*) begin
        case (1'b1)
            uart_glb_cfg_rd   : rsp_data = {{(DLEN-32){1'b0}}, uart_glb_cfg_r};
            uart_txq_cap_rd   : rsp_data = TXQ_DP[DLEN-1:0];
            uart_txq_len_rd   : rsp_data = {{(DLEN-TXQ_AW-1){1'b0}}, txq_len};
            uart_rxq_cap_rd   : rsp_data = RXQ_DP[DLEN-1:0];
            uart_rxq_len_rd   : rsp_data = {{(DLEN-RXQ_AW-1){1'b0}}, rxq_len};
            uart_rxq_dat_rd   : rsp_data = {{(DLEN-8){1'b0}}, rx_deq_dat};
            uart_ie_rd        : rsp_data = {{(DLEN-2){1'b0}}, uart_rx_ie_r, uart_tx_ie_r};
            uart_ip_rd        : rsp_data = {{(DLEN-2){1'b0}}, uart_rx_ip, uart_tx_ip};
            uart_tx_irq_th_rd : rsp_data = {{(DLEN-TXQ_AW-1){1'b0}}, uart_tx_irq_th_r};
            uart_rx_irq_th_rd : rsp_data = {{(DLEN-TXQ_AW-1){1'b0}}, uart_rx_irq_th_r};
            default           : rsp_data = {DLEN{1'b0}};
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rsp_data_r <= {DLEN{1'b0}};
        end
        else begin
            if (uart_psel & (~uart_penable)) begin
                rsp_data_r <= #UDLY rsp_data;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rsp_vld_r <= 1'b0;
        end
        else begin
            if (uart_psel & (~uart_penable)) begin
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
            if (uart_psel & (~uart_penable) & addr_mismatch) begin
                rsp_excp_r <= #UDLY 1'b1;
            end
            else begin
                rsp_excp_r <= #UDLY 1'b0;
            end
        end
    end

endmodule

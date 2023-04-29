//************************************************************
// See LICENSE for license details.
//
// Module: uv_spi_apb
//
// Designer: Owen
//
// Description:
//      SPI master with APB interface.
//************************************************************

`timescale 1ns / 1ps

module uv_spi_apb
#(
    parameter ALEN                  = 12,
    parameter DLEN                  = 32,
    parameter MLEN                  = DLEN / 8,
    parameter TXQ_AW                = 3,
    parameter TXQ_DP                = 2**TXQ_AW,
    parameter TXQ_DW                = 32,
    parameter RXQ_AW                = 3,
    parameter RXQ_DP                = 2**RXQ_AW,
    parameter RXQ_DW                = 32,
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

    // Serial ports.
    output [CS_NUM-1:0]             spi_cs,
    output                          spi_sck,
    output                          spi_mosi,
    input                           spi_miso,

    // Interrupt request.
    output                          spi_irq
);

    wire   [CS_NUM-1:0]             def_idle;
    wire   [CS_NUM-1:0]             spi_mask;
    wire                            spi_cpol;
    wire                            spi_cpha;
    wire                            spi_rxen;
    wire   [4:0]                    spi_unit;
    wire   [7:0]                    sck_dly;
    wire   [15:0]                   clk_div;
    wire                            endian;

    wire                            txq_clr;
    wire                            rxq_clr;
    wire   [TXQ_AW:0]               txq_len;
    wire   [RXQ_AW:0]               rxq_len;

    wire                            tx_enq_rdy;
    wire                            tx_enq_vld;
    wire   [31:0]                   tx_enq_dat;

    wire                            tx_deq_rdy;
    wire                            tx_deq_vld;
    wire   [31:0]                   tx_deq_dat;

    wire                            rx_enq_rdy;
    wire                            rx_enq_vld;
    wire   [31:0]                   rx_enq_dat;

    wire                            rx_deq_rdy;
    wire                            rx_deq_vld;
    wire   [31:0]                   rx_deq_dat;

    uv_spi_rtx
    #(
        .CS_NUM                     ( CS_NUM            )
    )
    u_spi_rtx
    (
        .clk                        ( clk               ),
        .rst_n                      ( rst_n             ),

        // Serial ports.
        .spi_cs                     ( spi_cs            ),
        .spi_sck                    ( spi_sck           ),
        .spi_mosi                   ( spi_mosi          ),
        .spi_miso                   ( spi_miso          ),

        // Config.
        .def_idle                   ( def_idle          ),
        .spi_mask                   ( spi_mask          ),
        .spi_cpol                   ( spi_cpol          ),
        .spi_cpha                   ( spi_cpha          ),
        .spi_rxen                   ( spi_rxen          ),
        .spi_unit                   ( spi_unit          ),
        .sck_dly                    ( sck_dly           ),
        .clk_div                    ( clk_div           ),
        .endian                     ( endian            ),

        // TX data from TXQ.
        .tx_rdy                     ( tx_deq_rdy        ),
        .tx_vld                     ( tx_deq_vld        ),
        .tx_dat                     ( tx_deq_dat        ),

        // RX data to RXQ.
        .rx_rdy                     ( rx_enq_rdy        ),
        .rx_vld                     ( rx_enq_vld        ),
        .rx_dat                     ( rx_enq_dat        )
    );

    uv_spi_reg
    #(
        .ALEN                       ( ALEN              ),
        .DLEN                       ( DLEN              ),
        .MLEN                       ( MLEN              ),
        .TXQ_AW                     ( TXQ_AW            ),
        .TXQ_DP                     ( TXQ_DP            ),
        .RXQ_AW                     ( RXQ_AW            ),
        .RXQ_DP                     ( RXQ_DP            ),
        .CS_NUM                     ( CS_NUM            )
    )
    u_spi_reg
    (
        .clk                        ( clk               ),
        .rst_n                      ( rst_n             ),

        // APB ports.
        .spi_psel                   ( spi_psel          ),
        .spi_penable                ( spi_penable       ),
        .spi_pprot                  ( spi_pprot         ),
        .spi_paddr                  ( spi_paddr         ),
        .spi_pstrb                  ( spi_pstrb         ),
        .spi_pwrite                 ( spi_pwrite        ),
        .spi_pwdata                 ( spi_pwdata        ),
        .spi_prdata                 ( spi_prdata        ),
        .spi_pready                 ( spi_pready        ),
        .spi_pslverr                ( spi_pslverr       ),

        // SPI control & status.
        .def_idle                   ( def_idle          ),
        .spi_mask                   ( spi_mask          ),
        .spi_cpol                   ( spi_cpol          ),
        .spi_cpha                   ( spi_cpha          ),
        .spi_rxen                   ( spi_rxen          ),
        .spi_unit                   ( spi_unit          ),
        .sck_dly                    ( sck_dly           ),
        .clk_div                    ( clk_div           ),
        .spi_irq                    ( spi_irq           ),
        .endian                     ( endian            ),

        .tx_enq_vld                 ( tx_enq_vld        ),
        .tx_enq_dat                 ( tx_enq_dat        ),
        .rx_deq_vld                 ( rx_deq_vld        ),
        .rx_deq_dat                 ( rx_deq_dat        ),

        .txq_clr                    ( txq_clr           ),
        .rxq_clr                    ( rxq_clr           ),
        .txq_len                    ( txq_len           ),
        .rxq_len                    ( rxq_len           )
    );

    uv_queue
    #(
        .DAT_WIDTH                  ( TXQ_DW            ),
        .PTR_WIDTH                  ( TXQ_AW            ),
        .QUE_DEPTH                  ( TXQ_DP            ),
        .ZERO_RDLY                  ( 1'b1              )
    )
    u_spi_txq
    (
        .clk                        ( clk               ),
        .rst_n                      ( rst_n             ),

        // Write channel.
        .wr_rdy                     ( tx_enq_rdy        ),
        .wr_vld                     ( tx_enq_vld        ),
        .wr_dat                     ( tx_enq_dat        ),

        // Read channel.
        .rd_rdy                     ( tx_deq_rdy        ),
        .rd_vld                     ( tx_deq_vld        ),
        .rd_dat                     ( tx_deq_dat        ),

        // Control & status.
        .clr                        ( txq_clr           ),
        .len                        ( txq_len           ),
        .full                       (                   ),
        .empty                      (                   )
    );

    uv_queue
    #(
        .DAT_WIDTH                  ( RXQ_DW            ),
        .PTR_WIDTH                  ( RXQ_AW            ),
        .QUE_DEPTH                  ( RXQ_DP            ),
        .ZERO_RDLY                  ( 1'b1              )
    )
    u_spi_rxq
    (
        .clk                        ( clk               ),
        .rst_n                      ( rst_n             ),

        // Write channel.
        .wr_rdy                     ( rx_enq_rdy        ),
        .wr_vld                     ( rx_enq_vld        ),
        .wr_dat                     ( rx_enq_dat        ),

        // Read channel.
        .rd_rdy                     ( rx_deq_rdy        ),
        .rd_vld                     ( rx_deq_vld        ),
        .rd_dat                     ( rx_deq_dat        ),

        // Control & status.
        .clr                        ( rxq_clr           ),
        .len                        ( rxq_len           ),
        .full                       (                   ),
        .empty                      (                   )
    );

endmodule

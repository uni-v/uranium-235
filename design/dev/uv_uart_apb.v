//************************************************************
// See LICENSE for license details.
//
// Module: uv_uart_apb
//
// Designer: Owen
//
// Description:
//      UART with APB interface.
//************************************************************

`timescale 1ns / 1ps

module uv_uart_apb
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

    // Serial ports.
    output                          uart_tx,
    input                           uart_rx,

    // Interrupt request.
    output                          uart_irq
);

    wire                            tx_en;
    wire                            rx_en;
    wire   [1:0]                    nbits;
    wire                            nstop;
    wire                            endian;
    wire   [15:0]                   clk_div;
    wire                            parity_en;
    wire   [1:0]                    parity_type;

    wire                            txq_clr;
    wire                            rxq_clr;
    wire   [TXQ_AW:0]               txq_len;
    wire   [RXQ_AW:0]               rxq_len;

    wire                            tx_enq_rdy;
    wire                            tx_enq_vld;
    wire   [7:0]                    tx_enq_dat;

    wire                            tx_deq_rdy;
    wire                            tx_deq_vld;
    wire   [7:0]                    tx_deq_dat;

    wire                            rx_enq_rdy;
    wire                            rx_enq_vld;
    wire   [7:0]                    rx_enq_dat;

    wire                            rx_deq_rdy;
    wire                            rx_deq_vld;
    wire   [7:0]                    rx_deq_dat;

    uv_uart_tx u_uart_tx
    (
        .clk                        ( clk               ),
        .rst_n                      ( rst_n             ),

        // Serial transmitting.
        .uart_tx                    ( uart_tx           ),

        // Configs.
        .tx_en                      ( tx_en             ),
        .nbits                      ( nbits             ),
        .nstop                      ( nstop             ),
        .endian                     ( endian            ),
        .clk_div                    ( clk_div           ),
        .parity_en                  ( parity_en         ),
        .parity_type                ( parity_type       ),

        // TX data from TXQ.
        .tx_rdy                     ( tx_deq_rdy        ),
        .tx_vld                     ( tx_deq_vld        ),
        .tx_dat                     ( tx_deq_dat        )
    );

    uv_uart_rx u_uart_rx
    (
        .clk                        ( clk               ),
        .rst_n                      ( rst_n             ),

        // Serial receiving.
        .uart_rx                    ( uart_rx           ),

        // Configs.
        .rx_en                      ( rx_en             ),
        .nbits                      ( nbits             ),
        .endian                     ( endian            ),
        .clk_div                    ( clk_div           ),
        .parity_en                  ( parity_en         ),
        .parity_type                ( parity_type       ),

        // RX data to RXQ.
        .rx_rdy                     ( rx_enq_rdy        ),
        .rx_vld                     ( rx_enq_vld        ),
        .rx_dat                     ( rx_enq_dat        )
    );

    uv_uart_reg
    #(
        .ALEN                       ( ALEN              ),
        .DLEN                       ( DLEN              ),
        .MLEN                       ( MLEN              ),
        .TXQ_AW                     ( TXQ_AW            ),
        .TXQ_DP                     ( TXQ_DP            ),
        .RXQ_AW                     ( RXQ_AW            ),
        .RXQ_DP                     ( RXQ_DP            )
    )
    u_uart_reg
    (
        .clk                        ( clk               ),
        .rst_n                      ( rst_n             ),

        // APB ports.
        .uart_psel                  ( uart_psel         ),
        .uart_penable               ( uart_penable      ),
        .uart_pprot                 ( uart_pprot        ),
        .uart_paddr                 ( uart_paddr        ),
        .uart_pstrb                 ( uart_pstrb        ),
        .uart_pwrite                ( uart_pwrite       ),
        .uart_pwdata                ( uart_pwdata       ),
        .uart_prdata                ( uart_prdata       ),
        .uart_pready                ( uart_pready       ),
        .uart_pslverr               ( uart_pslverr      ),

        // UART control & status.
        .tx_en                      ( tx_en             ),
        .rx_en                      ( rx_en             ),
        .nbits                      ( nbits             ),
        .nstop                      ( nstop             ),
        .endian                     ( endian            ),
        .clk_div                    ( clk_div           ),
        .parity_en                  ( parity_en         ),
        .parity_type                ( parity_type       ),
        .uart_irq                   ( uart_irq          ),

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
        .DAT_WIDTH                  ( 8                 ),
        .PTR_WIDTH                  ( TXQ_AW            ),
        .QUE_DEPTH                  ( TXQ_DP            ),
        .ZERO_RDLY                  ( 1'b1              )
    )
    u_uart_txq
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
        .DAT_WIDTH                  ( 8                 ),
        .PTR_WIDTH                  ( RXQ_AW            ),
        .QUE_DEPTH                  ( RXQ_DP            ),
        .ZERO_RDLY                  ( 1'b1              )
    )
    u_uart_rxq
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

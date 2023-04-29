//************************************************************
// See LICENSE for license details.
//
// Module: uv_i2c_apb
//
// Designer: Owen
//
// Description:
//      I2C with APB interface.
//      FIXME: To be verificated!
//************************************************************

`timescale 1ns / 1ps

module uv_i2c_apb
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

    // I2C ports.
    input                           i2c_scl_in,
    output                          i2c_scl_out,
    output                          i2c_scl_oen,
    input                           i2c_sda_in,
    output                          i2c_sda_out,
    output                          i2c_sda_oen,

    // Interrupt request.
    output                          i2c_irq
);

    wire                            i2c_start;
    wire                            i2c_busy;
    wire                            i2c_nack;
    wire                            i2c_nscl;

    wire   [7:0]                    nframes;
    wire   [15:0]                   sda_dly;
    wire   [15:0]                   clk_div;

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

    uv_i2c_rtx u_i2c_rtx
    (
        .clk                        ( clk               ),
        .rst_n                      ( rst_n             ),

        .i2c_scl_in                 ( i2c_scl_in        ),
        .i2c_scl_out                ( i2c_scl_out       ),
        .i2c_scl_oen                ( i2c_scl_oen       ),
        .i2c_sda_in                 ( i2c_sda_in        ),
        .i2c_sda_out                ( i2c_sda_out       ),
        .i2c_sda_oen                ( i2c_sda_oen       ),

        // Control & status.
        .i2c_start                  ( i2c_start         ),
        .i2c_busy                   ( i2c_busy          ),
        .i2c_nack                   ( i2c_nack          ),
        .i2c_nscl                   ( i2c_nscl          ),

        // Configs.
        .nframes                    ( nframes           ),
        .sda_dly                    ( sda_dly           ),
        .clk_div                    ( clk_div           ),

        // TX data from TXQ.
        .tx_rdy                     ( tx_deq_rdy        ),
        .tx_vld                     ( tx_deq_vld        ),
        .tx_dat                     ( tx_deq_dat        ),

        // RX data to RXQ.
        .rx_rdy                     ( rx_enq_rdy        ),
        .rx_vld                     ( rx_enq_vld        ),
        .rx_dat                     ( rx_enq_dat        )
    );

    uv_i2c_reg
    #(
        .ALEN                       ( ALEN              ),
        .DLEN                       ( DLEN              ),
        .MLEN                       ( MLEN              ),
        .TXQ_AW                     ( TXQ_AW            ),
        .TXQ_DP                     ( TXQ_DP            ),
        .RXQ_AW                     ( RXQ_AW            ),
        .RXQ_DP                     ( RXQ_DP            )
    )
    u_i2c_reg
    (
        .clk                        ( clk               ),
        .rst_n                      ( rst_n             ),

        // APB ports.
        .i2c_psel                   ( i2c_psel          ),
        .i2c_penable                ( i2c_penable       ),
        .i2c_pprot                  ( i2c_pprot         ),
        .i2c_paddr                  ( i2c_paddr         ),
        .i2c_pstrb                  ( i2c_pstrb         ),
        .i2c_pwrite                 ( i2c_pwrite        ),
        .i2c_pwdata                 ( i2c_pwdata        ),
        .i2c_prdata                 ( i2c_prdata        ),
        .i2c_pready                 ( i2c_pready        ),
        .i2c_pslverr                ( i2c_pslverr       ),

        // I2C control & status.
        .i2c_start                  ( i2c_start         ),
        .i2c_busy                   ( i2c_busy          ),
        .i2c_nack                   ( i2c_nack          ),
        .i2c_nscl                   ( i2c_nscl          ),

        // I2C configs.
        .nframes                    ( nframes           ),
        .sda_dly                    ( sda_dly           ),
        .clk_div                    ( clk_div           ),

        // Queue operations.
        .tx_enq_vld                 ( tx_enq_vld        ),
        .tx_enq_dat                 ( tx_enq_dat        ),
        .rx_deq_vld                 ( rx_deq_vld        ),
        .rx_deq_dat                 ( rx_deq_dat        ),

        .txq_clr                    ( txq_clr           ),
        .rxq_clr                    ( rxq_clr           ),
        .txq_len                    ( txq_len           ),
        .rxq_len                    ( rxq_len           ),
        .i2c_irq                    ( i2c_irq           )
    );

    uv_queue
    #(
        .DAT_WIDTH                  ( 8                 ),
        .PTR_WIDTH                  ( TXQ_AW            ),
        .QUE_DEPTH                  ( TXQ_DP            ),
        .ZERO_RDLY                  ( 1'b1              )
    )
    u_i2c_txq
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
    u_i2c_rxq
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

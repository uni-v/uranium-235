//************************************************************
// See LICENSE for license details.
//
// Module: uv_spi_rxq
//
// Designer: Owen
//
// Description:
//      RX queue to receive data from SPI slaves.
//************************************************************

`timescale 1ns / 1ps

module uv_spi_rxq
#(
    parameter QUE_AW = 3,
    parameter QUE_DP = 2**QUE_AW,
    parameter QUE_DW = 32
)
(
    input                           clk,
    input                           rst_n,

    output                          enq_rdy,
    input                           enq_vld,
    input  [QUE_DW-1:0]             enq_dat,

    output                          deq_rdy,
    input                           deq_vld,
    output [QUE_DW-1:0]             deq_dat,

    input                           que_clr,
    output [QUE_AW:0]               que_len
);

    uv_queue
    #(
        .DAT_WIDTH                  ( QUE_DW            ),
        .PTR_WIDTH                  ( QUE_AW            ),
        .QUE_DEPTH                  ( QUE_DP            ),
        .ZERO_RDLY                  ( 1'b1              ),
    )
    u_que
    (
        .clk                        ( clk               ),
        .rst_n                      ( rst_n             ),

        // Write channel.
        .wr_rdy                     ( enq_rdy           ),
        .wr_vld                     ( enq_vld           ),
        .wr_dat                     ( enq_dat           ),

        // Read channel.
        .rd_rdy                     ( deq_rdy           ),
        .rd_vld                     ( deq_vld           ),
        .rd_dat                     ( deq_dat           ),

        // Control & status.
        .clr                        ( que_clr           ),
        .len                        ( que_len           ),
        .full                       (                   ),
        .empty                      (                   )
    );

endmodule

//************************************************************
// See LICENSE for license details.
//
// Module: uv_stack
//
// Designer: Owen
//
// Description:
//      Last-In-First-Out Stack.
//************************************************************

`timescale 1ns / 1ps

module uv_stack
#(
    parameter DAT_WIDTH         = 32,
    parameter PTR_WIDTH         = 3,
    parameter QUE_DEPTH         = 2**PTR_WIDTH,
    parameter ZERO_RDLY         = 1'b1  // 1'b0: delay 1 cycle after read enabling; 1'b1: no delay.
)
(
    input                       clk,
    input                       rst_n,

    // Write channel.
    input                       wr,
    input  [PTR_WIDTH-1:0]      wr_ptr,
    input  [DAT_WIDTH-1:0]      wr_dat,

    // Read channel.
    input                       rd,
    input  [PTR_WIDTH-1:0]      rd_ptr,
    output [DAT_WIDTH-1:0]      rd_dat,

    // Control & status.
    input                       clr,
    output [PTR_WIDTH:0]        len
);

    localparam UDLY             = 1;
    genvar i;


endmodule

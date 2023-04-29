//************************************************************
// See LICENSE for license details.
//
// Module: uv_arb_fp
//
// Designer: Owen
//
// Description:
//      Fixed-priority arbiter.
//************************************************************

`timescale 1ns / 1ps

module uv_arb_fp
#(
    parameter WIDTH = 2
)
(
    input                   clk,
    input                   rst_n,
    input  [WIDTH-1:0]      req,
    output [WIDTH-1:0]      grant
);

    wire   [WIDTH*2-1:0]    req_d;
    wire   [WIDTH*2-1:0]    req_sub;
    wire   [WIDTH*2-1:0]    grant_d;

    assign req_d            = {req, req};
    assign req_sub          = req_d - 1'b1;
    assign grant_d          = req_d & (~req_sub);
    assign grant            = grant_d[WIDTH-1:0] | grant_d[2*WIDTH-1:WIDTH];

endmodule

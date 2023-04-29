//************************************************************
// See LICENSE for license details.
//
// Module: uv_arb_rr
//
// Designer: Owen
//
// Description:
//      Round-robin arbiter.
//************************************************************

`timescale 1ns / 1ps

module uv_arb_rr
#(
    parameter WIDTH = 2
)
(
    input                   clk,
    input                   rst_n,
    input  [WIDTH-1:0]      req,
    output [WIDTH-1:0]      grant
);

    localparam UDLY         = 1;

    wire   [WIDTH*2-1:0]    req_d;
    wire   [WIDTH*2-1:0]    req_sub;
    wire   [WIDTH*2-1:0]    grant_d;
    reg    [WIDTH-1:0]      prio_r;

    assign req_d            = {req, req};
    assign req_sub          = req_d - prio_r;
    assign grant_d          = req_d & (~req_sub);
    assign grant            = grant_d[WIDTH-1:0] | grant_d[2*WIDTH-1:WIDTH];

    // Update priority according to the previous grant.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            prio_r <= {{(WIDTH-1){1'b0}}, 1'b1};
        end
        else begin
            if (|req) begin
                prio_r <= #UDLY {grant[WIDTH-2:0], grant[WIDTH-1]};
            end
        end
    end

endmodule

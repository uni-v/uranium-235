//************************************************************
// See LICENSE for license details.
//
// Module: uv_dbg
//
// Designer: Owen
//
// Description:
//      FIXME: Debug model to be implemented.
//************************************************************

`timescale 1ns / 1ps

module uv_dbg
#(
    parameter ALEN                  = 12,
    parameter DLEN                  = 32,
    parameter MLEN                  = DLEN / 8
)
(
    input                           clk,
    input                           rst_n,

    input                           dbg_req_vld,
    output                          dbg_req_rdy,
    input                           dbg_req_read,
    input  [ALEN-1:0]               dbg_req_addr,
    input  [MLEN-1:0]               dbg_req_mask,
    input  [DLEN-1:0]               dbg_req_data,

    output                          dbg_rsp_vld,
    input                           dbg_rsp_rdy,
    output [1:0]                    dbg_rsp_excp,
    output [DLEN-1:0]               dbg_rsp_data
);

    localparam UDLY = 1;

    reg                             rsp_vld_r;

    assign dbg_req_rdy              = 1'b1;
    assign dbg_rsp_vld              = rsp_vld_r;
    assign dbg_rsp_excp             = 2'b0;
    assign dbg_rsp_data             = {DLEN{1'b1}};

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rsp_vld_r <= 1'b0;
        end
        else begin
            if (dbg_req_vld & dbg_req_rdy) begin
                rsp_vld_r <= #UDLY 1'b1;
            end
            else if (dbg_rsp_vld & dbg_rsp_rdy) begin
                rsp_vld_r <= #UDLY 1'b0;
            end
        end
    end

endmodule

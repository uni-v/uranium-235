//************************************************************
// See LICENSE for license details.
//
// Module: uv_eflash
//
// Designer: Owen
//
// Description:
//      FIXME: eFlash model to be implemented.
//************************************************************

`timescale 1ns / 1ps

module uv_eflash
#(
    parameter ALEN                  = 32,
    parameter DLEN                  = 32,
    parameter MLEN                  = DLEN / 8,
    parameter EFLASH_AW             = 18,
    parameter EFLASH_DP             = 2**EFLASH_AW
)
(
    input                           clk,
    input                           rst_n,

    input                           eflash_req_vld,
    output                          eflash_req_rdy,
    input                           eflash_req_read,
    input  [ALEN-1:0]               eflash_req_addr,
    input  [MLEN-1:0]               eflash_req_mask,
    input  [DLEN-1:0]               eflash_req_data,

    output                          eflash_rsp_vld,
    input                           eflash_rsp_rdy,
    output [1:0]                    eflash_rsp_excp,
    output [DLEN-1:0]               eflash_rsp_data
);

    localparam UDLY = 1;
    localparam OFFSET_AW = $clog2(DLEN / 8);

    reg                             rsp_vld_r; 

    assign eflash_req_rdy           = 1'b1;
    assign eflash_rsp_vld           = rsp_vld_r;
    assign eflash_rsp_excp          = 2'b0;
    assign eflash_rsp_data          = {DLEN{1'b1}};

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rsp_vld_r <= 1'b0;
        end
        else begin
            if (eflash_req_vld & eflash_req_rdy) begin
                rsp_vld_r <= #UDLY 1'b1;
            end
            else if (eflash_rsp_vld & eflash_rsp_rdy) begin
                rsp_vld_r <= #UDLY 1'b0;
            end
        end
    end

endmodule

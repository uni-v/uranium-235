//************************************************************
// See LICENSE for license details.
//
// Module: uv_bus_fab_1x2
//
// Designer: Owen
//
// Description:
//      Bus fabric with 1 master port and 2 slave ports.
//************************************************************

`timescale 1ns / 1ps

module uv_bus_fab_1x2
#(
    parameter ALEN              = 32,
    parameter DLEN              = 32,
    parameter MLEN              = DLEN / 8,
    parameter PIPE_STAGE        = 0,
    parameter SLV0_BASE_LSB     = 31,
    parameter SLV0_BASE_ADDR    = 1'h0,
    parameter SLV1_BASE_LSB     = 31,
    parameter SLV1_BASE_ADDR    = 1'h1
)
(
    input                       clk,
    input                       rst_n,

    // Master.
    input                       mst_req_vld,
    output                      mst_req_rdy,
    input                       mst_req_read,
    input  [ALEN-1:0]           mst_req_addr,
    input  [MLEN-1:0]           mst_req_mask,
    input  [DLEN-1:0]           mst_req_data,

    output                      mst_rsp_vld,
    input                       mst_rsp_rdy,
    output [1:0]                mst_rsp_excp,
    output [DLEN-1:0]           mst_rsp_data,

    // Slave 0.
    output                      slv0_req_vld,
    input                       slv0_req_rdy,
    output                      slv0_req_read,
    output [ALEN-1:0]           slv0_req_addr,
    output [MLEN-1:0]           slv0_req_mask,
    output [DLEN-1:0]           slv0_req_data,

    input                       slv0_rsp_vld,
    output                      slv0_rsp_rdy,
    input  [1:0]                slv0_rsp_excp,
    input  [DLEN-1:0]           slv0_rsp_data,

    // Slave 1.
    output                      slv1_req_vld,
    input                       slv1_req_rdy,
    output                      slv1_req_read,
    output [ALEN-1:0]           slv1_req_addr,
    output [MLEN-1:0]           slv1_req_mask,
    output [DLEN-1:0]           slv1_req_data,

    input                       slv1_rsp_vld,
    output                      slv1_rsp_rdy,
    input  [1:0]                slv1_rsp_excp,
    input  [DLEN-1:0]           slv1_rsp_data
);

    localparam MST_PORT_NUM         = 1;
    localparam SLV_PORT_NUM         = 2;

    // 1D slave ports.
    wire [SLV_PORT_NUM-1:0]         slv_req_vld;
    wire [SLV_PORT_NUM-1:0]         slv_req_rdy;
    wire [SLV_PORT_NUM-1:0]         slv_req_read;
    wire [SLV_PORT_NUM*ALEN-1:0]    slv_req_addr;
    wire [SLV_PORT_NUM*MLEN-1:0]    slv_req_mask;
    wire [SLV_PORT_NUM*DLEN-1:0]    slv_req_data;
    wire [SLV_PORT_NUM-1:0]         slv_rsp_vld;
    wire [SLV_PORT_NUM-1:0]         slv_rsp_rdy;
    wire [SLV_PORT_NUM*2-1:0]       slv_rsp_excp;
    wire [SLV_PORT_NUM*DLEN-1:0]    slv_rsp_data;

    assign slv_req_rdy  = {slv1_req_rdy , slv0_req_rdy };
    assign slv_rsp_vld  = {slv1_rsp_vld , slv0_rsp_vld };
    assign slv_rsp_excp = {slv1_rsp_excp, slv0_rsp_excp};
    assign slv_rsp_data = {slv1_rsp_data, slv0_rsp_data};
    assign {slv1_req_vld , slv0_req_vld } = slv_req_vld ;
    assign {slv1_req_read, slv0_req_read} = slv_req_read;
    assign {slv1_req_addr, slv0_req_addr} = slv_req_addr;
    assign {slv1_req_mask, slv0_req_mask} = slv_req_mask;
    assign {slv1_req_data, slv0_req_data} = slv_req_data;
    assign {slv1_rsp_rdy , slv0_rsp_rdy } = slv_rsp_rdy ;

    uv_bus_fab
    #(
        .ALEN                       ( ALEN              ),
        .DLEN                       ( DLEN              ),
        .MLEN                       ( MLEN              ),
        .PIPE_STAGE                 ( PIPE_STAGE        ),
        .MST_PORT_NUM               ( MST_PORT_NUM      ),
        .SLV_PORT_NUM               ( SLV_PORT_NUM      ),
        .SLV0_BASE_LSB              ( SLV0_BASE_LSB     ),
        .SLV0_BASE_ADDR             ( SLV0_BASE_ADDR    ),
        .SLV1_BASE_LSB              ( SLV1_BASE_LSB     ),
        .SLV1_BASE_ADDR             ( SLV1_BASE_ADDR    )
    )
    u_bus_fab_gnrl
    (
        .clk                        ( clk               ),
        .rst_n                      ( rst_n             ),

        // Masters.
        .mst_dev_vld                ( 1'b1              ),
        .mst_req_vld                ( mst_req_vld       ),
        .mst_req_rdy                ( mst_req_rdy       ),
        .mst_req_read               ( mst_req_read      ),
        .mst_req_addr               ( mst_req_addr      ),
        .mst_req_mask               ( mst_req_mask      ),
        .mst_req_data               ( mst_req_data      ),
        .mst_rsp_vld                ( mst_rsp_vld       ),
        .mst_rsp_rdy                ( mst_rsp_rdy       ),
        .mst_rsp_excp               ( mst_rsp_excp      ),
        .mst_rsp_data               ( mst_rsp_data      ),

        // Slaves.
        .slv_dev_vld                ( 2'b11             ),
        .slv_req_vld                ( slv_req_vld       ),
        .slv_req_rdy                ( slv_req_rdy       ),
        .slv_req_read               ( slv_req_read      ),
        .slv_req_addr               ( slv_req_addr      ),
        .slv_req_mask               ( slv_req_mask      ),
        .slv_req_data               ( slv_req_data      ),
        .slv_rsp_vld                ( slv_rsp_vld       ),
        .slv_rsp_rdy                ( slv_rsp_rdy       ),
        .slv_rsp_excp               ( slv_rsp_excp      ),
        .slv_rsp_data               ( slv_rsp_data      )
    );

endmodule

//************************************************************
// See LICENSE for license details.
//
// Module: uv_biu
//
// Designer: Owen
//
// Description:
//      Bus Interface Unit.
//************************************************************

`timescale 1ns / 1ps

module uv_biu
#(
    parameter ALEN              = 32,
    parameter DLEN              = 32,
    parameter MLEN              = DLEN / 8,
    parameter MEM_BASE_LSB      = 31,
    parameter MEM_BASE_ADDR     = 1'h1,
    parameter DEV_BASE_LSB      = 31,
    parameter DEV_BASE_ADDR     = 1'h0
)
(
    input                       clk,
    input                       rst_n,

    // Inst fetching from ucore.
    input                       if_req_vld,
    output                      if_req_rdy,
    input  [ALEN-1:0]           if_req_addr,

    output                      if_rsp_vld,
    input                       if_rsp_rdy,
    output [1:0]                if_rsp_excp,
    output [DLEN-1:0]           if_rsp_data,

    // Load-store from ucore.
    input                       ls_req_vld,
    output                      ls_req_rdy,
    input                       ls_req_read,
    input  [ALEN-1:0]           ls_req_addr,
    input  [MLEN-1:0]           ls_req_mask,
    input  [DLEN-1:0]           ls_req_data,

    output                      ls_rsp_vld,
    input                       ls_rsp_rdy,
    output [1:0]                ls_rsp_excp,
    output [DLEN-1:0]           ls_rsp_data,

    // Access to instruction memory.
    output                      mem_i_req_vld,
    input                       mem_i_req_rdy,
    output [ALEN-1:0]           mem_i_req_addr,

    input                       mem_i_rsp_vld,
    output                      mem_i_rsp_rdy,
    input  [1:0]                mem_i_rsp_excp,
    input  [DLEN-1:0]           mem_i_rsp_data,

    // Access to data memory.
    output                      mem_d_req_vld,
    input                       mem_d_req_rdy,
    output                      mem_d_req_read,
    output [ALEN-1:0]           mem_d_req_addr,
    output [MLEN-1:0]           mem_d_req_mask,
    output [DLEN-1:0]           mem_d_req_data,

    input                       mem_d_rsp_vld,
    output                      mem_d_rsp_rdy,
    input  [1:0]                mem_d_rsp_excp,
    input  [DLEN-1:0]           mem_d_rsp_data,

    // Access to system bus (instruction channel).
    output                      dev_i_req_vld,
    input                       dev_i_req_rdy,
    output [ALEN-1:0]           dev_i_req_addr,

    input                       dev_i_rsp_vld,
    output                      dev_i_rsp_rdy,
    input  [1:0]                dev_i_rsp_excp,
    input  [DLEN-1:0]           dev_i_rsp_data,

    // Access to system bus (data channel).
    output                      dev_d_req_vld,
    input                       dev_d_req_rdy,
    output                      dev_d_req_read,
    output [ALEN-1:0]           dev_d_req_addr,
    output [MLEN-1:0]           dev_d_req_mask,
    output [DLEN-1:0]           dev_d_req_data,

    input                       dev_d_rsp_vld,
    output                      dev_d_rsp_rdy,
    input  [1:0]                dev_d_rsp_excp,
    input  [DLEN-1:0]           dev_d_rsp_data
);

    localparam UDLY             = 1;

    reg                         if_rsp_rdy_r;
    reg                         if_req_vld_r;
    reg  [ALEN-1:0]             if_req_addr_r;

    reg                         ls_rsp_rdy_r;
    reg                         ls_req_vld_r;
    reg                         ls_req_read_r;
    reg  [ALEN-1:0]             ls_req_addr_r;
    reg  [MLEN-1:0]             ls_req_mask_r;
    reg  [DLEN-1:0]             ls_req_data_r;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            if_rsp_rdy_r  <= 1'b0;
            if_req_vld_r  <= 1'b0;
            if_req_addr_r <= {ALEN{1'b0}};
        end
        else begin
            if_rsp_rdy_r  <= #UDLY if_rsp_rdy;
            if_req_vld_r  <= #UDLY if_req_vld;
            if_req_addr_r <= #UDLY if_req_addr;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            ls_rsp_rdy_r  <= 1'b0;
            ls_req_vld_r  <= 1'b0;
            ls_req_read_r <= 1'b0;
            ls_req_addr_r <= {ALEN{1'b0}};
            ls_req_mask_r <= {MLEN{1'b0}};
            ls_req_data_r <= {DLEN{1'b0}};
        end
        else begin
            ls_rsp_rdy_r  <= #UDLY ls_rsp_rdy;
            ls_req_vld_r  <= #UDLY ls_req_vld;
            ls_req_read_r <= #UDLY ls_req_read;
            ls_req_addr_r <= #UDLY ls_req_addr;
            ls_req_mask_r <= #UDLY ls_req_mask;
            ls_req_data_r <= #UDLY ls_req_data;
        end
    end

    uv_bus_fab_1x2
    #(
        .ALEN                   ( ALEN              ),
        .DLEN                   ( DLEN              ),
        .MLEN                   ( MLEN              ),
        .SLV0_BASE_LSB          ( MEM_BASE_LSB      ),
        .SLV0_BASE_ADDR         ( MEM_BASE_ADDR     ),
        .SLV1_BASE_LSB          ( DEV_BASE_LSB      ),
        .SLV1_BASE_ADDR         ( DEV_BASE_ADDR     )
    )
    u_ibus_fab
    (
        .clk                    ( clk               ),
        .rst_n                  ( rst_n             ),

        // Master.
        .mst_req_vld            ( if_req_vld        ),
        .mst_req_rdy            ( if_req_rdy        ),
        .mst_req_read           ( 1'b1              ),
        .mst_req_addr           ( if_req_addr       ),
        .mst_req_mask           ( {MLEN{1'b1}}      ),
        .mst_req_data           ( {DLEN{1'b0}}      ),

        .mst_rsp_vld            ( if_rsp_vld        ),
        .mst_rsp_rdy            ( if_rsp_rdy        ),
        .mst_rsp_excp           ( if_rsp_excp       ),
        .mst_rsp_data           ( if_rsp_data       ),

        // Slave 0.
        .slv0_req_vld           ( mem_i_req_vld     ),
        .slv0_req_rdy           ( mem_i_req_rdy     ),
        .slv0_req_read          (                   ),
        .slv0_req_addr          ( mem_i_req_addr    ),
        .slv0_req_mask          (                   ),
        .slv0_req_data          (                   ),

        .slv0_rsp_vld           ( mem_i_rsp_vld     ),
        .slv0_rsp_rdy           ( mem_i_rsp_rdy     ),
        .slv0_rsp_excp          ( mem_i_rsp_excp    ),
        .slv0_rsp_data          ( mem_i_rsp_data    ),

        // Slave 1.
        .slv1_req_vld           ( dev_i_req_vld     ),
        .slv1_req_rdy           ( dev_i_req_rdy     ),
        .slv1_req_read          (                   ),
        .slv1_req_addr          ( dev_i_req_addr    ),
        .slv1_req_mask          (                   ),
        .slv1_req_data          (                   ),

        .slv1_rsp_vld           ( dev_i_rsp_vld     ),
        .slv1_rsp_rdy           ( dev_i_rsp_rdy     ),
        .slv1_rsp_excp          ( dev_i_rsp_excp    ),
        .slv1_rsp_data          ( dev_i_rsp_data    )
    );

    uv_bus_fab_1x2
    #(
        .ALEN                   ( ALEN              ),
        .DLEN                   ( DLEN              ),
        .MLEN                   ( MLEN              ),
        .SLV0_BASE_LSB          ( MEM_BASE_LSB      ),
        .SLV0_BASE_ADDR         ( MEM_BASE_ADDR     ),
        .SLV1_BASE_LSB          ( DEV_BASE_LSB      ),
        .SLV1_BASE_ADDR         ( DEV_BASE_ADDR     )
    )
    u_dbus_fab
    (
        .clk                    ( clk               ),
        .rst_n                  ( rst_n             ),

        // Master.
        .mst_req_vld            ( ls_req_vld        ),
        .mst_req_rdy            ( ls_req_rdy        ),
        .mst_req_read           ( ls_req_read       ),
        .mst_req_addr           ( ls_req_addr       ),
        .mst_req_mask           ( ls_req_mask       ),
        .mst_req_data           ( ls_req_data       ),

        .mst_rsp_vld            ( ls_rsp_vld        ),
        .mst_rsp_rdy            ( ls_rsp_rdy        ),
        .mst_rsp_excp           ( ls_rsp_excp       ),
        .mst_rsp_data           ( ls_rsp_data       ),

        // Slave 0.
        .slv0_req_vld           ( mem_d_req_vld     ),
        .slv0_req_rdy           ( mem_d_req_rdy     ),
        .slv0_req_read          ( mem_d_req_read    ),
        .slv0_req_addr          ( mem_d_req_addr    ),
        .slv0_req_mask          ( mem_d_req_mask    ),
        .slv0_req_data          ( mem_d_req_data    ),

        .slv0_rsp_vld           ( mem_d_rsp_vld     ),
        .slv0_rsp_rdy           ( mem_d_rsp_rdy     ),
        .slv0_rsp_excp          ( mem_d_rsp_excp    ),
        .slv0_rsp_data          ( mem_d_rsp_data    ),

        // Slave 1.
        .slv1_req_vld           ( dev_d_req_vld     ),
        .slv1_req_rdy           ( dev_d_req_rdy     ),
        .slv1_req_read          ( dev_d_req_read    ),
        .slv1_req_addr          ( dev_d_req_addr    ),
        .slv1_req_mask          ( dev_d_req_mask    ),
        .slv1_req_data          ( dev_d_req_data    ),

        .slv1_rsp_vld           ( dev_d_rsp_vld     ),
        .slv1_rsp_rdy           ( dev_d_rsp_rdy     ),
        .slv1_rsp_excp          ( dev_d_rsp_excp    ),
        .slv1_rsp_data          ( dev_d_rsp_data    )
    );

endmodule

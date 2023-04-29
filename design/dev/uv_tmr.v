//************************************************************
// See LICENSE for license details.
//
// Module: uv_tmr
//
// Designer: Owen
//
// Description:
//      General-purpose Timer.
//************************************************************

`timescale 1ns / 1ps

module uv_tmr
#(
    parameter ALEN                  = 12,
    parameter DLEN                  = 32,
    parameter MLEN                  = DLEN / 8
)
(
    input                           clk,
    input                           rst_n,

    // Low-speed clock for timer.
    input                           low_clk,

    input                           tmr_req_vld,
    output                          tmr_req_rdy,
    input                           tmr_req_read,
    input  [ALEN-1:0]               tmr_req_addr,
    input  [MLEN-1:0]               tmr_req_mask,
    input  [DLEN-1:0]               tmr_req_data,

    output                          tmr_rsp_vld,
    input                           tmr_rsp_rdy,
    output [1:0]                    tmr_rsp_excp,
    output [DLEN-1:0]               tmr_rsp_data,

    output                          tmr_irq,
    output                          tmr_evt
);

    localparam BUS_PIPE             = 1'b1;

    wire                            tmr_psel;
    wire                            tmr_penable;
    wire [2:0]                      tmr_pprot;
    wire [ALEN-1:0]                 tmr_paddr;
    wire [MLEN-1:0]                 tmr_pstrb;
    wire                            tmr_pwrite;
    wire [DLEN-1:0]                 tmr_pwdata;
    wire [DLEN-1:0]                 tmr_prdata;
    wire                            tmr_pready;
    wire                            tmr_pslverr;

    uv_bus_to_apb
    #(
        .ALEN                       ( ALEN                  ),
        .DLEN                       ( DLEN                  ),
        .MLEN                       ( MLEN                  ),
        .PIPE                       ( BUS_PIPE              )
    )
    u_bus_to_apb
    (
        .clk                        ( clk                   ),
        .rst_n                      ( rst_n                 ),

        // Bus ports.
        .bus_req_vld                ( tmr_req_vld           ),
        .bus_req_rdy                ( tmr_req_rdy           ),
        .bus_req_read               ( tmr_req_read          ),
        .bus_req_addr               ( tmr_req_addr          ),
        .bus_req_mask               ( tmr_req_mask          ),
        .bus_req_data               ( tmr_req_data          ),

        .bus_rsp_vld                ( tmr_rsp_vld           ),
        .bus_rsp_rdy                ( tmr_rsp_rdy           ),
        .bus_rsp_excp               ( tmr_rsp_excp          ),
        .bus_rsp_data               ( tmr_rsp_data          ),

        // APB ports.
        .apb_psel                   ( tmr_psel              ),
        .apb_penable                ( tmr_penable           ),
        .apb_pprot                  ( tmr_pprot             ),
        .apb_paddr                  ( tmr_paddr             ),
        .apb_pstrb                  ( tmr_pstrb             ),
        .apb_pwrite                 ( tmr_pwrite            ),
        .apb_pwdata                 ( tmr_pwdata            ),
        .apb_prdata                 ( tmr_prdata            ),
        .apb_pready                 ( tmr_pready            ),
        .apb_pslverr                ( tmr_pslverr           )
    );

    uv_tmr_apb
    #(
        .ALEN                       ( ALEN                  ),
        .DLEN                       ( DLEN                  ),
        .MLEN                       ( MLEN                  )
    )
    u_tmr_apb
    (
        .clk                        ( clk                   ),
        .rst_n                      ( rst_n                 ),

        // Low-speed clock for timer.
        .low_clk                    ( low_clk               ),

        // APB ports.
        .tmr_psel                   ( tmr_psel              ),
        .tmr_penable                ( tmr_penable           ),
        .tmr_pprot                  ( tmr_pprot             ),
        .tmr_paddr                  ( tmr_paddr             ),
        .tmr_pstrb                  ( tmr_pstrb             ),
        .tmr_pwrite                 ( tmr_pwrite            ),
        .tmr_pwdata                 ( tmr_pwdata            ),
        .tmr_prdata                 ( tmr_prdata            ),
        .tmr_pready                 ( tmr_pready            ),
        .tmr_pslverr                ( tmr_pslverr           ),

        // TMR control & status.
        .tmr_irq                    ( tmr_irq               ),
        .tmr_evt                    ( tmr_evt               )
    );

endmodule

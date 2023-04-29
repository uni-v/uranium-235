//************************************************************
// See LICENSE for license details.
//
// Module: uv_wdt
//
// Designer: Owen
//
// Description:
//      Watch Dog Timer.
//************************************************************

`timescale 1ns / 1ps

module uv_wdt
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

    input                           wdt_req_vld,
    output                          wdt_req_rdy,
    input                           wdt_req_read,
    input  [ALEN-1:0]               wdt_req_addr,
    input  [MLEN-1:0]               wdt_req_mask,
    input  [DLEN-1:0]               wdt_req_data,

    output                          wdt_rsp_vld,
    input                           wdt_rsp_rdy,
    output [1:0]                    wdt_rsp_excp,
    output [DLEN-1:0]               wdt_rsp_data,

    output                          wdt_irq,
    output                          wdt_rst_n
);

    localparam BUS_PIPE             = 1'b1;

    wire                            wdt_psel;
    wire                            wdt_penable;
    wire [2:0]                      wdt_pprot;
    wire [ALEN-1:0]                 wdt_paddr;
    wire [MLEN-1:0]                 wdt_pstrb;
    wire                            wdt_pwrite;
    wire [DLEN-1:0]                 wdt_pwdata;
    wire [DLEN-1:0]                 wdt_prdata;
    wire                            wdt_pready;
    wire                            wdt_pslverr;

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
        .bus_req_vld                ( wdt_req_vld           ),
        .bus_req_rdy                ( wdt_req_rdy           ),
        .bus_req_read               ( wdt_req_read          ),
        .bus_req_addr               ( wdt_req_addr          ),
        .bus_req_mask               ( wdt_req_mask          ),
        .bus_req_data               ( wdt_req_data          ),

        .bus_rsp_vld                ( wdt_rsp_vld           ),
        .bus_rsp_rdy                ( wdt_rsp_rdy           ),
        .bus_rsp_excp               ( wdt_rsp_excp          ),
        .bus_rsp_data               ( wdt_rsp_data          ),

        // APB ports.
        .apb_psel                   ( wdt_psel              ),
        .apb_penable                ( wdt_penable           ),
        .apb_pprot                  ( wdt_pprot             ),
        .apb_paddr                  ( wdt_paddr             ),
        .apb_pstrb                  ( wdt_pstrb             ),
        .apb_pwrite                 ( wdt_pwrite            ),
        .apb_pwdata                 ( wdt_pwdata            ),
        .apb_prdata                 ( wdt_prdata            ),
        .apb_pready                 ( wdt_pready            ),
        .apb_pslverr                ( wdt_pslverr           )
    );

    uv_wdt_apb
    #(
        .ALEN                       ( ALEN                  ),
        .DLEN                       ( DLEN                  ),
        .MLEN                       ( MLEN                  )
    )
    u_wdt_apb
    (
        .clk                        ( clk                   ),
        .rst_n                      ( rst_n                 ),

        // Low-speed clock for timer.
        .low_clk                    ( low_clk               ),

        // APB ports.
        .wdt_psel                   ( wdt_psel              ),
        .wdt_penable                ( wdt_penable           ),
        .wdt_pprot                  ( wdt_pprot             ),
        .wdt_paddr                  ( wdt_paddr             ),
        .wdt_pstrb                  ( wdt_pstrb             ),
        .wdt_pwrite                 ( wdt_pwrite            ),
        .wdt_pwdata                 ( wdt_pwdata            ),
        .wdt_prdata                 ( wdt_prdata            ),
        .wdt_pready                 ( wdt_pready            ),
        .wdt_pslverr                ( wdt_pslverr           ),

        // WDT control.
        .wdt_irq                    ( wdt_irq               ),
        .wdt_rst_n                  ( wdt_rst_n             )
    );

endmodule

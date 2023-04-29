//************************************************************
// See LICENSE for license details.
//
// Module: uv_wdt_apb
//
// Designer: Owen
//
// Description:
//      Watch Dog Timer with APB bus interface.
//************************************************************

`timescale 1ns / 1ps

module uv_wdt_apb
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

    // APB ports.
    input                           wdt_psel,
    input                           wdt_penable,
    input  [2:0]                    wdt_pprot,
    input  [ALEN-1:0]               wdt_paddr,
    input  [MLEN-1:0]               wdt_pstrb,
    input                           wdt_pwrite,
    input  [DLEN-1:0]               wdt_pwdata,
    output [DLEN-1:0]               wdt_prdata,
    output                          wdt_pready,
    output                          wdt_pslverr,

    // WDT control.
    output                          wdt_irq,
    output                          wdt_rst_n
);

    localparam REG_WDT_CFG          = 0;
    localparam REG_WDT_VAL          = 1;
    localparam REG_WDT_CMP          = 2;
    localparam REG_WDT_FEED         = 3;

    wire                            tmr_evt;

    assign wdt_rst_n                = ~tmr_evt;

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
        .tmr_psel                   ( wdt_psel              ),
        .tmr_penable                ( wdt_penable           ),
        .tmr_pprot                  ( wdt_pprot             ),
        .tmr_paddr                  ( wdt_paddr             ),
        .tmr_pstrb                  ( wdt_pstrb             ),
        .tmr_pwrite                 ( wdt_pwrite            ),
        .tmr_pwdata                 ( wdt_pwdata            ),
        .tmr_prdata                 ( wdt_prdata            ),
        .tmr_pready                 ( wdt_pready            ),
        .tmr_pslverr                ( wdt_pslverr           ),

        // TMR control & status.
        .tmr_irq                    ( wdt_irq               ),
        .tmr_evt                    ( tmr_evt               )
    );

endmodule

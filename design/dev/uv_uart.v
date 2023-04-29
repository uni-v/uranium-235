//************************************************************
// See LICENSE for license details.
//
// Module: uv_uart
//
// Designer: Owen
//
// Description:
//      UART module for UV-Soc.
//************************************************************

`timescale 1ns / 1ps

module uv_uart
#(
    parameter ALEN                  = 12,
    parameter DLEN                  = 32,
    parameter MLEN                  = DLEN / 8,
    parameter TXQ_AW                = 3,
    parameter TXQ_DP                = 2**TXQ_AW,
    parameter RXQ_AW                = 3,
    parameter RXQ_DP                = 2**RXQ_AW
)
(
    input                           clk,
    input                           rst_n,

    input                           uart_req_vld,
    output                          uart_req_rdy,
    input                           uart_req_read,
    input  [ALEN-1:0]               uart_req_addr,
    input  [MLEN-1:0]               uart_req_mask,
    input  [DLEN-1:0]               uart_req_data,

    output                          uart_rsp_vld,
    input                           uart_rsp_rdy,
    output [1:0]                    uart_rsp_excp,
    output [DLEN-1:0]               uart_rsp_data,

    input                           uart_rx,
    output                          uart_tx,

    output                          uart_irq
);

    localparam BUS_PIPE             = 1'b1;

    wire                            uart_psel;
    wire                            uart_penable;
    wire   [2:0]                    uart_pprot;
    wire   [ALEN-1:0]               uart_paddr;
    wire   [MLEN-1:0]               uart_pstrb;
    wire                            uart_pwrite;
    wire   [DLEN-1:0]               uart_pwdata;
    wire   [DLEN-1:0]               uart_prdata;
    wire                            uart_pready;
    wire                            uart_pslverr;

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
        .bus_req_vld                ( uart_req_vld          ),
        .bus_req_rdy                ( uart_req_rdy          ),
        .bus_req_read               ( uart_req_read         ),
        .bus_req_addr               ( uart_req_addr         ),
        .bus_req_mask               ( uart_req_mask         ),
        .bus_req_data               ( uart_req_data         ),

        .bus_rsp_vld                ( uart_rsp_vld          ),
        .bus_rsp_rdy                ( uart_rsp_rdy          ),
        .bus_rsp_excp               ( uart_rsp_excp         ),
        .bus_rsp_data               ( uart_rsp_data         ),

        // APB ports.
        .apb_psel                   ( uart_psel             ),
        .apb_penable                ( uart_penable          ),
        .apb_pprot                  ( uart_pprot            ),
        .apb_paddr                  ( uart_paddr            ),
        .apb_pstrb                  ( uart_pstrb            ),
        .apb_pwrite                 ( uart_pwrite           ),
        .apb_pwdata                 ( uart_pwdata           ),
        .apb_prdata                 ( uart_prdata           ),
        .apb_pready                 ( uart_pready           ),
        .apb_pslverr                ( uart_pslverr          )
    );

    uv_uart_apb
    #(
        .ALEN                       ( ALEN                  ),
        .DLEN                       ( DLEN                  ),
        .MLEN                       ( MLEN                  ),
        .TXQ_AW                     ( TXQ_AW                ),
        .TXQ_DP                     ( TXQ_DP                ),
        .RXQ_AW                     ( RXQ_AW                ),
        .RXQ_DP                     ( RXQ_DP                )
    )
    u_uart_apb
    (
        .clk                        ( clk                   ),
        .rst_n                      ( rst_n                 ),

        // APB ports.
        .uart_psel                  ( uart_psel             ),
        .uart_penable               ( uart_penable          ),
        .uart_pprot                 ( uart_pprot            ),
        .uart_paddr                 ( uart_paddr            ),
        .uart_pstrb                 ( uart_pstrb            ),
        .uart_pwrite                ( uart_pwrite           ),
        .uart_pwdata                ( uart_pwdata           ),
        .uart_prdata                ( uart_prdata           ),
        .uart_pready                ( uart_pready           ),
        .uart_pslverr               ( uart_pslverr          ),

        // Serial ports.
        .uart_tx                    ( uart_tx               ),
        .uart_rx                    ( uart_rx               ),

        // Interrupt request.
        .uart_irq                   ( uart_irq              )
    );

endmodule

//************************************************************
// See LICENSE for license details.
//
// Module: uv_gpio
//
// Designer: Owen
//
// Description:
//      GPIO module for UV-Soc.
//************************************************************

`timescale 1ns / 1ps

module uv_gpio
#(
    parameter ALEN                  = 12,
    parameter DLEN                  = 32,
    parameter MLEN                  = DLEN / 8,
    parameter IO_NUM                = 32,
    parameter MUX_IO_NUM            = 10
)
(
    input                           clk,
    input                           rst_n,

    input                           gpio_req_vld,
    output                          gpio_req_rdy,
    input                           gpio_req_read,
    input  [ALEN-1:0]               gpio_req_addr,
    input  [MLEN-1:0]               gpio_req_mask,
    input  [DLEN-1:0]               gpio_req_data,

    output                          gpio_rsp_vld,
    input                           gpio_rsp_rdy,
    output [1:0]                    gpio_rsp_excp,
    output [DLEN-1:0]               gpio_rsp_data,

    input                           gpio_mode,

    output [IO_NUM-1:0]             gpio_pu,
    output [IO_NUM-1:0]             gpio_pd,
    output [IO_NUM-1:0]             gpio_ie,
    input  [IO_NUM-1:0]             gpio_in,
    output [IO_NUM-1:0]             gpio_oe,
    output [IO_NUM-1:0]             gpio_out,
    output [IO_NUM-1:0]             gpio_irq
);

    localparam BUS_PIPE             = 1'b1;

    wire                            gpio_psel;
    wire                            gpio_penable;
    wire   [2:0]                    gpio_pprot;
    wire   [ALEN-1:0]               gpio_paddr;
    wire   [MLEN-1:0]               gpio_pstrb;
    wire                            gpio_pwrite;
    wire   [DLEN-1:0]               gpio_pwdata;
    wire   [DLEN-1:0]               gpio_prdata;
    wire                            gpio_pready;
    wire                            gpio_pslverr;

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
        .bus_req_vld                ( gpio_req_vld          ),
        .bus_req_rdy                ( gpio_req_rdy          ),
        .bus_req_read               ( gpio_req_read         ),
        .bus_req_addr               ( gpio_req_addr         ),
        .bus_req_mask               ( gpio_req_mask         ),
        .bus_req_data               ( gpio_req_data         ),

        .bus_rsp_vld                ( gpio_rsp_vld          ),
        .bus_rsp_rdy                ( gpio_rsp_rdy          ),
        .bus_rsp_excp               ( gpio_rsp_excp         ),
        .bus_rsp_data               ( gpio_rsp_data         ),

        // APB ports.
        .apb_psel                   ( gpio_psel             ),
        .apb_penable                ( gpio_penable          ),
        .apb_pprot                  ( gpio_pprot            ),
        .apb_paddr                  ( gpio_paddr            ),
        .apb_pstrb                  ( gpio_pstrb            ),
        .apb_pwrite                 ( gpio_pwrite           ),
        .apb_pwdata                 ( gpio_pwdata           ),
        .apb_prdata                 ( gpio_prdata           ),
        .apb_pready                 ( gpio_pready           ),
        .apb_pslverr                ( gpio_pslverr          )
    );

    uv_gpio_apb
    #(
        .ALEN                       ( ALEN                  ),
        .DLEN                       ( DLEN                  ),
        .MLEN                       ( MLEN                  ),
        .IO_NUM                     ( IO_NUM                ),
        .MUX_IO_NUM                 ( MUX_IO_NUM            )
    )
    u_gpio_apb
    (
        .clk                        ( clk                   ),
        .rst_n                      ( rst_n                 ),

        // APB ports.
        .gpio_psel                  ( gpio_psel             ),
        .gpio_penable               ( gpio_penable          ),
        .gpio_pprot                 ( gpio_pprot            ),
        .gpio_paddr                 ( gpio_paddr            ),
        .gpio_pstrb                 ( gpio_pstrb            ),
        .gpio_pwrite                ( gpio_pwrite           ),
        .gpio_pwdata                ( gpio_pwdata           ),
        .gpio_prdata                ( gpio_prdata           ),
        .gpio_pready                ( gpio_pready           ),
        .gpio_pslverr               ( gpio_pslverr          ),

        .gpio_mode                  ( gpio_mode             ),

        .gpio_pu                    ( gpio_pu               ),
        .gpio_pd                    ( gpio_pd               ),
        .gpio_ie                    ( gpio_ie               ),
        .gpio_in                    ( gpio_in               ),
        .gpio_oe                    ( gpio_oe               ),
        .gpio_out                   ( gpio_out              ),
        .gpio_irq                   ( gpio_irq              )
    );

endmodule

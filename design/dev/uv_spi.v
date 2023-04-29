//************************************************************
// See LICENSE for license details.
//
// Module: uv_spi
//
// Designer: Owen
//
// Description:
//      SPI (Serial Peripheral Interface) module for UV-Soc.
//************************************************************

`timescale 1ns / 1ps

module uv_spi
#(
    parameter ALEN                  = 12,
    parameter DLEN                  = 32,
    parameter MLEN                  = DLEN / 8,
    parameter TXQ_AW                = 3,
    parameter TXQ_DP                = 2**TXQ_AW,
    parameter TXQ_DW                = 32,
    parameter RXQ_AW                = 3,
    parameter RXQ_DP                = 2**RXQ_AW,
    parameter RXQ_DW                = 32,
    parameter CS_NUM                = 4
)
(
    input                           clk,
    input                           rst_n,

    input                           spi_req_vld,
    output                          spi_req_rdy,
    input                           spi_req_read,
    input  [ALEN-1:0]               spi_req_addr,
    input  [MLEN-1:0]               spi_req_mask,
    input  [DLEN-1:0]               spi_req_data,

    output                          spi_rsp_vld,
    input                           spi_rsp_rdy,
    output [1:0]                    spi_rsp_excp,
    output [DLEN-1:0]               spi_rsp_data,

    output [CS_NUM-1:0]             spi_cs,
    output                          spi_sck,
    output                          spi_mosi,
    input                           spi_miso,

    output                          spi_irq
);

    localparam BUS_PIPE             = 1'b1;

    wire                            spi_psel;
    wire                            spi_penable;
    wire   [2:0]                    spi_pprot;
    wire   [ALEN-1:0]               spi_paddr;
    wire   [MLEN-1:0]               spi_pstrb;
    wire                            spi_pwrite;
    wire   [DLEN-1:0]               spi_pwdata;
    wire   [DLEN-1:0]               spi_prdata;
    wire                            spi_pready;
    wire                            spi_pslverr;

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
        .bus_req_vld                ( spi_req_vld           ),
        .bus_req_rdy                ( spi_req_rdy           ),
        .bus_req_read               ( spi_req_read          ),
        .bus_req_addr               ( spi_req_addr          ),
        .bus_req_mask               ( spi_req_mask          ),
        .bus_req_data               ( spi_req_data          ),

        .bus_rsp_vld                ( spi_rsp_vld           ),
        .bus_rsp_rdy                ( spi_rsp_rdy           ),
        .bus_rsp_excp               ( spi_rsp_excp          ),
        .bus_rsp_data               ( spi_rsp_data          ),

        // APB ports.
        .apb_psel                   ( spi_psel              ),
        .apb_penable                ( spi_penable           ),
        .apb_pprot                  ( spi_pprot             ),
        .apb_paddr                  ( spi_paddr             ),
        .apb_pstrb                  ( spi_pstrb             ),
        .apb_pwrite                 ( spi_pwrite            ),
        .apb_pwdata                 ( spi_pwdata            ),
        .apb_prdata                 ( spi_prdata            ),
        .apb_pready                 ( spi_pready            ),
        .apb_pslverr                ( spi_pslverr           )
    );

    uv_spi_apb
    #(
        .ALEN                       ( ALEN                  ),
        .DLEN                       ( DLEN                  ),
        .MLEN                       ( MLEN                  ),
        .TXQ_AW                     ( TXQ_AW                ),
        .TXQ_DP                     ( TXQ_DP                ),
        .TXQ_DW                     ( TXQ_DW                ),
        .RXQ_AW                     ( RXQ_AW                ),
        .RXQ_DP                     ( RXQ_DP                ),
        .RXQ_DW                     ( RXQ_DW                ),
        .CS_NUM                     ( CS_NUM                )
    )
    u_spi_apb
    (
        .clk                        ( clk                   ),
        .rst_n                      ( rst_n                 ),

        // APB ports.
        .spi_psel                   ( spi_psel              ),
        .spi_penable                ( spi_penable           ),
        .spi_pprot                  ( spi_pprot             ),
        .spi_paddr                  ( spi_paddr             ),
        .spi_pstrb                  ( spi_pstrb             ),
        .spi_pwrite                 ( spi_pwrite            ),
        .spi_pwdata                 ( spi_pwdata            ),
        .spi_prdata                 ( spi_prdata            ),
        .spi_pready                 ( spi_pready            ),
        .spi_pslverr                ( spi_pslverr           ),

        // Serial ports.
        .spi_cs                     ( spi_cs                ),
        .spi_sck                    ( spi_sck               ),
        .spi_mosi                   ( spi_mosi              ),
        .spi_miso                   ( spi_miso              ),

        // Interrupt request.
        .spi_irq                    ( spi_irq               )
    );

endmodule

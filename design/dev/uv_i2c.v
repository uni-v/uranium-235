//************************************************************
// See LICENSE for license details.
//
// Module: uv_i2c
//
// Designer: Owen
//
// Description:
//      I2C (Inter-Integrated Circuit) module for UV-Soc.
//      FIXME: To be verificated!
//************************************************************

`timescale 1ns / 1ps

module uv_i2c
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

    input                           i2c_req_vld,
    output                          i2c_req_rdy,
    input                           i2c_req_read,
    input  [ALEN-1:0]               i2c_req_addr,
    input  [MLEN-1:0]               i2c_req_mask,
    input  [DLEN-1:0]               i2c_req_data,

    output                          i2c_rsp_vld,
    input                           i2c_rsp_rdy,
    output [1:0]                    i2c_rsp_excp,
    output [DLEN-1:0]               i2c_rsp_data,

    input                           i2c_scl_in,
    output                          i2c_scl_out,
    output                          i2c_scl_oen,
    input                           i2c_sda_in,
    output                          i2c_sda_out,
    output                          i2c_sda_oen,

    output                          i2c_irq
);

    localparam BUS_PIPE             = 1'b1;

    wire                            i2c_psel;
    wire                            i2c_penable;
    wire   [2:0]                    i2c_pprot;
    wire   [ALEN-1:0]               i2c_paddr;
    wire   [MLEN-1:0]               i2c_pstrb;
    wire                            i2c_pwrite;
    wire   [DLEN-1:0]               i2c_pwdata;
    wire   [DLEN-1:0]               i2c_prdata;
    wire                            i2c_pready;
    wire                            i2c_pslverr;

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
        .bus_req_vld                ( i2c_req_vld           ),
        .bus_req_rdy                ( i2c_req_rdy           ),
        .bus_req_read               ( i2c_req_read          ),
        .bus_req_addr               ( i2c_req_addr          ),
        .bus_req_mask               ( i2c_req_mask          ),
        .bus_req_data               ( i2c_req_data          ),

        .bus_rsp_vld                ( i2c_rsp_vld           ),
        .bus_rsp_rdy                ( i2c_rsp_rdy           ),
        .bus_rsp_excp               ( i2c_rsp_excp          ),
        .bus_rsp_data               ( i2c_rsp_data          ),

        // APB ports.
        .apb_psel                   ( i2c_psel              ),
        .apb_penable                ( i2c_penable           ),
        .apb_pprot                  ( i2c_pprot             ),
        .apb_paddr                  ( i2c_paddr             ),
        .apb_pstrb                  ( i2c_pstrb             ),
        .apb_pwrite                 ( i2c_pwrite            ),
        .apb_pwdata                 ( i2c_pwdata            ),
        .apb_prdata                 ( i2c_prdata            ),
        .apb_pready                 ( i2c_pready            ),
        .apb_pslverr                ( i2c_pslverr           )
    );

    uv_i2c_apb
    #(
        .ALEN                       ( ALEN                  ),
        .DLEN                       ( DLEN                  ),
        .MLEN                       ( MLEN                  ),
        .TXQ_AW                     ( TXQ_AW                ),
        .TXQ_DP                     ( TXQ_DP                ),
        .RXQ_AW                     ( RXQ_AW                ),
        .RXQ_DP                     ( RXQ_DP                )
    )
    u_i2c_apb
    (
        .clk                        ( clk                   ),
        .rst_n                      ( rst_n                 ),

        // APB ports.
        .i2c_psel                   ( i2c_psel              ),
        .i2c_penable                ( i2c_penable           ),
        .i2c_pprot                  ( i2c_pprot             ),
        .i2c_paddr                  ( i2c_paddr             ),
        .i2c_pstrb                  ( i2c_pstrb             ),
        .i2c_pwrite                 ( i2c_pwrite            ),
        .i2c_pwdata                 ( i2c_pwdata            ),
        .i2c_prdata                 ( i2c_prdata            ),
        .i2c_pready                 ( i2c_pready            ),
        .i2c_pslverr                ( i2c_pslverr           ),

        // I2C ports.
        .i2c_scl_in                 ( i2c_scl_in            ),
        .i2c_scl_out                ( i2c_scl_out           ),
        .i2c_scl_oen                ( i2c_scl_oen           ),
        .i2c_sda_in                 ( i2c_sda_in            ),
        .i2c_sda_out                ( i2c_sda_out           ),
        .i2c_sda_oen                ( i2c_sda_oen           ),

        // Interrupt request.
        .i2c_irq                    ( i2c_irq               )
    );

endmodule

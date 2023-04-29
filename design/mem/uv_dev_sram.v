//************************************************************
// See LICENSE for license details.
//
// Module: uv_dev_sram
//
// Designer: Owen
//
// Description:
//      SRAM connected to devbus.
//************************************************************

`timescale 1ns / 1ps

module uv_dev_sram
#(
    parameter ALEN                  = 32,
    parameter DLEN                  = 32,
    parameter MLEN                  = DLEN / 8,
    parameter SRAM_AW               = 10,
    parameter SRAM_DP               = 2**SRAM_AW
)
(
    input                           clk,
    input                           rst_n,

    input                           sram_req_vld,
    output                          sram_req_rdy,
    input                           sram_req_read,
    input  [ALEN-1:0]               sram_req_addr,
    input  [MLEN-1:0]               sram_req_mask,
    input  [DLEN-1:0]               sram_req_data,

    output                          sram_rsp_vld,
    input                           sram_rsp_rdy,
    output [1:0]                    sram_rsp_excp,
    output [DLEN-1:0]               sram_rsp_data
);

    wire                            sram_ce;
    wire                            sram_we;
    wire [SRAM_AW-1:0]              sram_addr;
    wire [DLEN-1:0]                 sram_wdat;
    wire [MLEN-1:0]                 sram_mask;
    wire [DLEN-1:0]                 sram_rdat;

    uv_sram_bus_ctrl
    #(
        .ALEN                       ( ALEN              ),
        .DLEN                       ( DLEN              ),
        .MLEN                       ( MLEN              ),
        .SRAM_AW                    ( SRAM_AW           ),
        .SRAM_DP                    ( SRAM_DP           )
    )
    u_sram_bus_ctrl
    (
        .clk                        ( clk               ),
        .rst_n                      ( rst_n             ),

        .sram_req_vld               ( sram_req_vld      ),
        .sram_req_rdy               ( sram_req_rdy      ),
        .sram_req_read              ( sram_req_read     ),
        .sram_req_addr              ( sram_req_addr     ),
        .sram_req_mask              ( sram_req_mask     ),
        .sram_req_data              ( sram_req_data     ),

        .sram_rsp_vld               ( sram_rsp_vld      ),
        .sram_rsp_rdy               ( sram_rsp_rdy      ),
        .sram_rsp_excp              ( sram_rsp_excp     ),
        .sram_rsp_data              ( sram_rsp_data     ),

        .sram_ce                    ( sram_ce           ),
        .sram_we                    ( sram_we           ),
        .sram_addr                  ( sram_addr         ),
        .sram_wdat                  ( sram_wdat         ),
        .sram_mask                  ( sram_mask         ),
        .sram_rdat                  ( sram_rdat         )
    );

`ifdef ASIC

    // RAM instantiation for specific process.

`elsif FPGA

    wire [3:0]                      sram_wea;

    assign sram_wea                 = {4{sram_we}} & sram_mask;

    uv_fpga_bram_32x16k u_ram
    (
        .clka                       ( clk               ),  // input wire clka
        .ena                        ( sram_ce           ),  // input wire ena
        .wea                        ( sram_wea          ),  // input wire [3 : 0] wea
        .addra                      ( sram_addr         ),  // input wire [13 : 0] addra
        .dina                       ( sram_wdat         ),  // input wire [31 : 0] dina
        .douta                      ( sram_rdat         )   // output wire [31 : 0] douta
    );

`else // SIMULATION

    uv_sram_sp
    #(
        .RAM_AW                     ( SRAM_AW           ),
        .RAM_DP                     ( SRAM_DP           ),
        .RAM_DW                     ( DLEN              ),
        .RAM_MW                     ( MLEN              ),
        .RAM_DLY                    ( 0                 )
    )
    u_ram
    (
        .clk                        ( clk               ),
        .ce                         ( sram_ce           ),
        .we                         ( sram_we           ),
        .a                          ( sram_addr         ),
        .d                          ( sram_wdat         ),
        .m                          ( sram_mask         ),
        .q                          ( sram_rdat         )
    );

`endif

endmodule

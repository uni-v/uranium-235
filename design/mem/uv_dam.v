//************************************************************
// See LICENSE for license details.
//
// Module: uv_dam
//
// Designer: Owen
//
// Description:
//      Directly Accessed Memory.
//************************************************************

`timescale 1ns / 1ps

module uv_dam
#(
    parameter PORT_AW               = 10,
    parameter PORT_DW               = 32,
    parameter PORT_MW               = PORT_DW / 8,
    parameter SRAM_DP               = 2**(PORT_AW - $clog2(PORT_MW))
)
(
    input                           clk,
    input                           rst_n,

    input                           port_a_req_vld,
    output                          port_a_req_rdy,
    input                           port_a_req_read,
    input  [PORT_AW-1:0]            port_a_req_addr,
    input  [PORT_MW-1:0]            port_a_req_mask,
    input  [PORT_DW-1:0]            port_a_req_data,
    output                          port_a_rsp_vld,
    input                           port_a_rsp_rdy,
    output [1:0]                    port_a_rsp_excp,
    output [PORT_DW-1:0]            port_a_rsp_data,

    input                           port_b_req_vld,
    output                          port_b_req_rdy,
    input                           port_b_req_read,
    input  [PORT_AW-1:0]            port_b_req_addr,
    input  [PORT_MW-1:0]            port_b_req_mask,
    input  [PORT_DW-1:0]            port_b_req_data,
    output                          port_b_rsp_vld,
    input                           port_b_rsp_rdy,
    output [1:0]                    port_b_rsp_excp,
    output [PORT_DW-1:0]            port_b_rsp_data
);

    localparam UDLY                 = 1;
    localparam BANK_AW              = PORT_AW - $clog2(PORT_MW) - 1;
    localparam BANK_DP              = SRAM_DP / 2;
    localparam BANK_DW              = PORT_DW;
    localparam BANK_MW              = PORT_MW;
    localparam BANK_A_BASE_LSB      = PORT_AW - 1;
    localparam BANK_A_BASE_BASE     = 1'b0;
    localparam BANK_B_BASE_LSB      = PORT_AW - 1;
    localparam BANK_B_BASE_BASE     = 1'b1;

    // Bank bus ports.
    wire                            bank_a_req_vld;
    wire                            bank_a_req_rdy;
    wire                            bank_a_req_read;
    wire [PORT_AW-1:0]              bank_a_req_addr;
    wire [PORT_MW-1:0]              bank_a_req_mask;
    wire [PORT_DW-1:0]              bank_a_req_data;
    wire                            bank_a_rsp_vld;
    wire                            bank_a_rsp_rdy;
    wire [1:0]                      bank_a_rsp_excp;
    wire [PORT_DW-1:0]              bank_a_rsp_data;

    wire                            bank_b_req_vld;
    wire                            bank_b_req_rdy;
    wire                            bank_b_req_read;
    wire [PORT_AW-1:0]              bank_b_req_addr;
    wire [PORT_MW-1:0]              bank_b_req_mask;
    wire [PORT_DW-1:0]              bank_b_req_data;
    wire                            bank_b_rsp_vld;
    wire                            bank_b_rsp_rdy;
    wire [1:0]                      bank_b_rsp_excp;
    wire [PORT_DW-1:0]              bank_b_rsp_data;

    // Bank ram ports.
    wire                            bank_a_ce;
    wire                            bank_a_we;
    wire [BANK_AW-1:0]              bank_a_addr;
    wire [BANK_DW-1:0]              bank_a_wdat;
    wire [BANK_MW-1:0]              bank_a_mask;
    wire [BANK_DW-1:0]              bank_a_rdat;

    wire                            bank_b_ce;
    wire                            bank_b_we;
    wire [BANK_AW-1:0]              bank_b_addr;
    wire [BANK_DW-1:0]              bank_b_wdat;
    wire [BANK_MW-1:0]              bank_b_mask;
    wire [BANK_DW-1:0]              bank_b_rdat;

    // Matrix.
    uv_bus_fab_2x2
    #(
        .ALEN                       ( PORT_AW           ),
        .DLEN                       ( PORT_DW           ),
        .MLEN                       ( PORT_MW           ),
        .PIPE_STAGE                 ( 0                 ),
        .SLV0_BASE_LSB              ( BANK_A_BASE_LSB   ),
        .SLV0_BASE_ADDR             ( BANK_A_BASE_BASE  ),
        .SLV1_BASE_LSB              ( BANK_B_BASE_LSB   ),
        .SLV1_BASE_ADDR             ( BANK_B_BASE_BASE  )
    )
    u_bus_fab
    (
        .clk                        ( clk               ),
        .rst_n                      ( rst_n             ),

        // Device enabling.
        .mst_dev_vld                ( 2'b11             ),
        .slv_dev_vld                ( 2'b11             ),

        // Masters.
        .mst0_req_vld               ( port_a_req_vld    ),
        .mst0_req_rdy               ( port_a_req_rdy    ),
        .mst0_req_read              ( port_a_req_read   ),
        .mst0_req_addr              ( port_a_req_addr   ),
        .mst0_req_mask              ( port_a_req_mask   ),
        .mst0_req_data              ( port_a_req_data   ),
        .mst0_rsp_vld               ( port_a_rsp_vld    ),
        .mst0_rsp_rdy               ( port_a_rsp_rdy    ),
        .mst0_rsp_excp              ( port_a_rsp_excp   ),
        .mst0_rsp_data              ( port_a_rsp_data   ),

        .mst1_req_vld               ( port_b_req_vld    ),
        .mst1_req_rdy               ( port_b_req_rdy    ),
        .mst1_req_read              ( port_b_req_read   ),
        .mst1_req_addr              ( port_b_req_addr   ),
        .mst1_req_mask              ( port_b_req_mask   ),
        .mst1_req_data              ( port_b_req_data   ),
        .mst1_rsp_vld               ( port_b_rsp_vld    ),
        .mst1_rsp_rdy               ( port_b_rsp_rdy    ),
        .mst1_rsp_excp              ( port_b_rsp_excp   ),
        .mst1_rsp_data              ( port_b_rsp_data   ),

        // Slaves.
        .slv0_req_vld               ( bank_a_req_vld    ),
        .slv0_req_rdy               ( bank_a_req_rdy    ),
        .slv0_req_read              ( bank_a_req_read   ),
        .slv0_req_addr              ( bank_a_req_addr   ),
        .slv0_req_mask              ( bank_a_req_mask   ),
        .slv0_req_data              ( bank_a_req_data   ),
        .slv0_rsp_vld               ( bank_a_rsp_vld    ),
        .slv0_rsp_rdy               ( bank_a_rsp_rdy    ),
        .slv0_rsp_excp              ( bank_a_rsp_excp   ),
        .slv0_rsp_data              ( bank_a_rsp_data   ),

        .slv1_req_vld               ( bank_b_req_vld    ),
        .slv1_req_rdy               ( bank_b_req_rdy    ),
        .slv1_req_read              ( bank_b_req_read   ),
        .slv1_req_addr              ( bank_b_req_addr   ),
        .slv1_req_mask              ( bank_b_req_mask   ),
        .slv1_req_data              ( bank_b_req_data   ),
        .slv1_rsp_vld               ( bank_b_rsp_vld    ),
        .slv1_rsp_rdy               ( bank_b_rsp_rdy    ),
        .slv1_rsp_excp              ( bank_b_rsp_excp   ),
        .slv1_rsp_data              ( bank_b_rsp_data   )
    );

    uv_sram_bus_ctrl
    #(
        .ALEN                       ( PORT_AW           ),
        .DLEN                       ( PORT_DW           ),
        .MLEN                       ( PORT_MW           ),
        .SRAM_AW                    ( BANK_AW           ),
        .SRAM_DP                    ( BANK_DP           )
    )
    u_bus_ctrl_a
    (
        .clk                        ( clk               ),
        .rst_n                      ( rst_n             ),

        .sram_req_vld               ( bank_a_req_vld    ),
        .sram_req_rdy               ( bank_a_req_rdy    ),
        .sram_req_read              ( bank_a_req_read   ),
        .sram_req_addr              ( bank_a_req_addr   ),
        .sram_req_mask              ( bank_a_req_mask   ),
        .sram_req_data              ( bank_a_req_data   ),
        .sram_rsp_vld               ( bank_a_rsp_vld    ),
        .sram_rsp_rdy               ( bank_a_rsp_rdy    ),
        .sram_rsp_excp              ( bank_a_rsp_excp   ),
        .sram_rsp_data              ( bank_a_rsp_data   ),

        .sram_ce                    ( bank_a_ce         ),
        .sram_we                    ( bank_a_we         ),
        .sram_addr                  ( bank_a_addr       ),
        .sram_wdat                  ( bank_a_wdat       ),
        .sram_mask                  ( bank_a_mask       ),
        .sram_rdat                  ( bank_a_rdat       )
    );

    uv_sram_bus_ctrl
    #(
        .ALEN                       ( PORT_AW           ),
        .DLEN                       ( PORT_DW           ),
        .MLEN                       ( PORT_MW           ),
        .SRAM_AW                    ( BANK_AW           ),
        .SRAM_DP                    ( BANK_DP           )
    )
    u_bus_ctrl_b
    (
        .clk                        ( clk               ),
        .rst_n                      ( rst_n             ),

        .sram_req_vld               ( bank_b_req_vld    ),
        .sram_req_rdy               ( bank_b_req_rdy    ),
        .sram_req_read              ( bank_b_req_read   ),
        .sram_req_addr              ( bank_b_req_addr   ),
        .sram_req_mask              ( bank_b_req_mask   ),
        .sram_req_data              ( bank_b_req_data   ),
        .sram_rsp_vld               ( bank_b_rsp_vld    ),
        .sram_rsp_rdy               ( bank_b_rsp_rdy    ),
        .sram_rsp_excp              ( bank_b_rsp_excp   ),
        .sram_rsp_data              ( bank_b_rsp_data   ),

        .sram_ce                    ( bank_b_ce         ),
        .sram_we                    ( bank_b_we         ),
        .sram_addr                  ( bank_b_addr       ),
        .sram_wdat                  ( bank_b_wdat       ),
        .sram_mask                  ( bank_b_mask       ),
        .sram_rdat                  ( bank_b_rdat       )
    );

`ifdef ASIC

    // RAM instantiation for specific process.

`elsif FPGA

    wire [3:0]                      bank_a_wea;
    wire [3:0]                      bank_b_wea;

    assign bank_a_wea               = {4{bank_a_we}} & bank_a_mask;
    assign bank_b_wea               = {4{bank_b_we}} & bank_b_mask;

    uv_fpga_bram_32x16k u_bank_a
    (
        .clka                       ( clk               ),  // input wire clka
        .ena                        ( bank_a_ce         ),  // input wire ena
        .wea                        ( bank_a_wea        ),  // input wire [3 : 0] wea
        .addra                      ( bank_a_addr       ),  // input wire [13 : 0] addra
        .dina                       ( bank_a_wdat       ),  // input wire [31 : 0] dina
        .douta                      ( bank_a_rdat       )   // output wire [31 : 0] douta
    );

    uv_fpga_bram_32x16k u_bank_b
    (
        .clka                       ( clk               ),  // input wire clka
        .ena                        ( bank_b_ce         ),  // input wire ena
        .wea                        ( bank_b_wea        ),  // input wire [3 : 0] wea
        .addra                      ( bank_b_addr       ),  // input wire [13 : 0] addra
        .dina                       ( bank_b_wdat       ),  // input wire [31 : 0] dina
        .douta                      ( bank_b_rdat       )   // output wire [31 : 0] douta
    );

`else // SIMULATION

    // BANK A.
    uv_sram_sp
    #(
        .RAM_AW                     ( BANK_AW           ),
        .RAM_DP                     ( BANK_DP           ),
        .RAM_DW                     ( BANK_DW           ),
        .RAM_MW                     ( BANK_MW           ),
        .RAM_DLY                    ( 0                 )
    )
    u_bank_a
    (
        .clk                        ( clk               ),
        .ce                         ( bank_a_ce         ),
        .we                         ( bank_a_we         ),
        .a                          ( bank_a_addr       ),
        .d                          ( bank_a_wdat       ),
        .m                          ( bank_a_mask       ),
        .q                          ( bank_a_rdat       )
    );

    // BANK B.
    uv_sram_sp
    #(
        .RAM_AW                     ( BANK_AW           ),
        .RAM_DP                     ( BANK_DP           ),
        .RAM_DW                     ( BANK_DW           ),
        .RAM_MW                     ( BANK_MW           ),
        .RAM_DLY                    ( 0                 )
    )
    u_bank_b
    (
        .clk                        ( clk               ),
        .ce                         ( bank_b_ce         ),
        .we                         ( bank_b_we         ),
        .a                          ( bank_b_addr       ),
        .d                          ( bank_b_wdat       ),
        .m                          ( bank_b_mask       ),
        .q                          ( bank_b_rdat       )
    );

`endif

endmodule

//************************************************************
// See LICENSE for license details.
//
// Module: uv_mul
//
// Designer: Owen
//
// Description:
//      Pipelined Multiplier (must be retimed at synthesis).
//************************************************************

`timescale 1ns / 1ps

module uv_mul
#(
    parameter MUL_DW        = 32,
    parameter PIPE_STAGE    = 3
)
(
    input                   clk,
    input                   rst_n,
    
    input                   req_vld,
    input                   req_sgn,
    input                   req_mix,
    input                   req_low,

    input  [MUL_DW-1:0]     req_opa,
    input  [MUL_DW-1:0]     req_opb,

    output                  rsp_vld,
    output [MUL_DW-1:0]     rsp_res
);

    wire [MUL_DW:0]         ext_opa;
    wire [MUL_DW:0]         ext_opb;
    wire [MUL_DW*2+1:0]     ext_res;
    wire [MUL_DW-1:0]       half_res;

    assign ext_opa          = {(req_sgn | req_mix) & req_opa[MUL_DW-1], req_opa};
    assign ext_opb          = {req_sgn & req_opb[MUL_DW-1], req_opb};
    assign ext_res          = $signed(ext_opa) * $signed(ext_opb);
    assign half_res         = req_low ? ext_res[MUL_DW-1:0] : ext_res[MUL_DW*2-1:MUL_DW];
    
    uv_pipe
    #(
        .PIPE_WIDTH         ( 1                 ),
        .PIPE_STAGE         ( PIPE_STAGE        )
    )
    u_pipe_vld
    (
        .clk                ( clk               ),
        .rst_n              ( rst_n             ),
        .in                 ( req_vld           ),                  
        .out                ( rsp_vld           )
    );

    uv_pipe
    #(
        .PIPE_WIDTH         ( MUL_DW            ),
        .PIPE_STAGE         ( PIPE_STAGE        )
    )
    u_pipe_res
    (
        .clk                ( clk               ),
        .rst_n              ( rst_n             ),
        .in                 ( half_res          ),                  
        .out                ( rsp_res           )
    );
    
endmodule

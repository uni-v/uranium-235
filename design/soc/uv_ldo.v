//************************************************************
// See LICENSE for license details.
//
// Module: uv_ldo
//
// Designer: Owen
//
// Description:
//      LDO simulation model.
//************************************************************

`timescale 1ns / 1ps

module uv_ldo
(
    input                       clk,
    input                       rst_n,

    // Config input.

    // Status output.

    output                      por_rst_n
);

`ifdef ASIC


`elsif FPGA

    assign por_rst_n = 1'b1;

`else // SIMULATION

    reg  por_rst_r;

    initial begin
        por_rst_r = 1'b0;
        repeat(20 + {$random(10)}) @(posedge clk);
        por_rst_r = 1'b1;
    end
    
    assign por_rst_n = ~por_rst_r;

`endif

endmodule

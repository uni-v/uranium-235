//************************************************************
// See LICENSE for license details.
//
// Module: uv_clk_gate
//
// Designer: Owen
//
// Description:
//      General clock gate for low power design.
//************************************************************

`timescale 1ns / 1ps

module uv_clk_gate
(
    input                   clk_in,
    input                   clk_en,
    output                  clk_out
);

`ifdef ASIC

    // Cell instantiation for specific process.

`elsif FPGA

    // Bypass clock gating for FPGA.
    assign clk_out = clk_in;

`else // SIMULATION

    reg en;

    // Latch.
    always @(*) begin
        if (~clk_in) begin
            en = clk_en;
        end
    end

    assign clk_out = clk_in & en;

`endif

endmodule

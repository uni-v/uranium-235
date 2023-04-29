//************************************************************
// See LICENSE for license details.
//
// Module: uv_regfile
//
// Designer: Owen
//
// Description:
//      Register file.
//************************************************************

`timescale 1ns / 1ps

module uv_regfile
#(
    parameter RF_AW = 5,
    parameter RF_DP = 2**RF_AW,
    parameter RF_DW = 32
)
(
    input                   clk,
    input                   rst_n,
    
    input                   wr_vld,
    input  [RF_AW-1:0]      wr_idx,
    input  [RF_DW-1:0]      wr_data,
    
    input  [RF_AW-1:0]      ra_idx,
    input  [RF_AW-1:0]      rb_idx,
    input  [RF_AW-1:0]      rc_idx,
    output [RF_DW-1:0]      ra_data,
    output [RF_DW-1:0]      rb_data,
    output [RF_DW-1:0]      rc_data
);

    localparam UDLY         = 1;
    genvar i;
    
    wire [RF_DW-1:0]        zero;
    reg  [RF_DW-1:0]        rf [0:RF_DP-1];
    
    // Bind zero to x0.
    assign zero = {RF_DW{1'b0}};
    
    always @* begin
        rf[0] = zero;
    end
    
    // Generate reg file writing for x1 ~ x31.
    generate
        for (i = 1; i < RF_DP; i = i + 1) begin: gen_rf_wr
            always @(posedge clk or negedge rst_n) begin
                if (~rst_n) begin
                    rf[i] <= {RF_DW{1'b0}};
                end
                else begin
                    if (wr_vld && (i == wr_idx)) begin
                        rf[i] <= #UDLY wr_data;
                    end
                end
            end
        end
    endgenerate
    
    // Response reg file reading for x0 ~ x31.
    assign ra_data = rf[ra_idx];
    assign rb_data = rf[rb_idx];
    assign rc_data = rf[rc_idx];

endmodule

//************************************************************
// See LICENSE for license details.
//
// Module: uv_sync
//
// Designer: Owen
//
// Description:
//      General purpose syncronizer.
//************************************************************

`timescale 1ns / 1ps

module uv_sync
#(
    parameter SYNC_WIDTH = 1,
    parameter SYNC_STAGE = 2
)
(
    input                   clk,
    input                   rst_n,
    input  [SYNC_WIDTH-1:0] in,                  
    output [SYNC_WIDTH-1:0] out
);

    localparam UDLY = 1;
    genvar i;

    reg [SYNC_WIDTH-1:0]    sync_r[0:SYNC_STAGE-1];

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            sync_r[0] <= {SYNC_WIDTH{1'b0}};
        end
        else begin
            sync_r[0] <= #UDLY in;
        end
    end

    generate
        for (i = 1; i < SYNC_STAGE; i = i + 1) begin: gen_sync_regs
            always @(posedge clk or negedge rst_n) begin
                if (~rst_n) begin
                    sync_r[i] <= {SYNC_WIDTH{1'b0}};
                end
                else begin
                    sync_r[i] <= #UDLY sync_r[i-1];
                end
            end
        end
    endgenerate

    assign out = sync_r[SYNC_STAGE-1];

endmodule

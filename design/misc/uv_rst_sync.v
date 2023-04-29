//************************************************************
// See LICENSE for license details.
//
// Module: uv_rst_sync
//
// Designer: Owen
//
// Description:
//      Syncronizer to handle asyncronized reset input.
//************************************************************

`timescale 1ns / 1ps

module uv_rst_sync
#(
    parameter SYNC_STAGE = 2
)
(
    input                   clk,
    input                   rst_n,
    output                  sync_rst_n
);

    localparam UDLY = 1;

    reg  [SYNC_STAGE-1:0]   sync_n_r;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            sync_n_r <= {SYNC_STAGE{1'b0}};
        end
        else begin
            sync_n_r <= {sync_n_r[SYNC_STAGE-2:0], 1'b1};
        end
    end

    assign sync_rst_n = sync_n_r[SYNC_STAGE-1];

endmodule

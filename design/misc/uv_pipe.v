//************************************************************
// See LICENSE for license details.
//
// Module: uv_pipe
//
// Designer: Owen
//
// Description:
//      Pipeline stages.
//************************************************************

`timescale 1ns / 1ps

module uv_pipe
#(
    parameter PIPE_WIDTH = 1,
    parameter PIPE_STAGE = 1
)
(
    input                   clk,
    input                   rst_n,
    input  [PIPE_WIDTH-1:0] in,                  
    output [PIPE_WIDTH-1:0] out
);

    localparam UDLY = 1;
    localparam REG_STAGE = PIPE_STAGE == 0 ? 1 : PIPE_STAGE;
    genvar i;

    reg [PIPE_WIDTH-1:0] pipe_r[0:REG_STAGE-1];

    generate
        if (PIPE_STAGE == 0) begin: gen_no_pipe
            assign out = in;
        end
        else begin: gen_pipe
            always @(posedge clk or negedge rst_n) begin
                if (~rst_n) begin
                    pipe_r[0] <= {PIPE_WIDTH{1'b0}};
                end
                else begin
                    pipe_r[0] <= #UDLY in;
                end
            end

            for (i = 1; i < PIPE_STAGE; i = i + 1) begin: gen_pipe_regs
                always @(posedge clk or negedge rst_n) begin
                    if (~rst_n) begin
                        pipe_r[i] <= {PIPE_WIDTH{1'b0}};
                    end
                    else begin
                        pipe_r[i] <= #UDLY pipe_r[i-1];
                    end
                end
            end

            assign out = pipe_r[PIPE_STAGE-1];
        end
    endgenerate

endmodule

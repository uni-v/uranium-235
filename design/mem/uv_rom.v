//************************************************************
// See LICENSE for license details.
//
// Module: uv_rom
//
// Designer: Owen
//
// Description:
//      Read-only Memory for Boot.
//************************************************************

`timescale 1ns / 1ps

module uv_rom
#(
    parameter ALEN                  = 26,
    parameter DLEN                  = 32,
    parameter MLEN                  = DLEN / 8,
    parameter ROM_AW                = 10
)
(
    input                           clk,
    input                           rst_n,

    input                           rom_req_vld,
    output                          rom_req_rdy,
    input                           rom_req_read,
    input  [ALEN-1:0]               rom_req_addr,
    input  [MLEN-1:0]               rom_req_mask,
    input  [DLEN-1:0]               rom_req_data,

    output                          rom_rsp_vld,
    input                           rom_rsp_rdy,
    output [1:0]                    rom_rsp_excp,
    output [DLEN-1:0]               rom_rsp_data
);

    localparam UDLY = 1;

    wire [ROM_AW-1:0]               rom_addr;
    wire [63:0]                     rom_data;

    wire [63:0]                     sft_data;
    wire [DLEN-1:0]                 rsp_data;

    reg                             rsp_vld_r;
    reg  [DLEN-1:0]                 rsp_data_r;

    assign rom_addr                 = rom_req_addr[ROM_AW+1:2];
    assign sft_data                 = rom_data >> {rom_req_addr[1:0], 3'b0};

    assign rom_req_rdy              = 1'b1;
    assign rom_rsp_vld              = rsp_vld_r;
    assign rom_rsp_excp             = 2'b0;
    assign rom_rsp_data             = rsp_data_r;

    generate
        if (DLEN > 32) begin: gen_rsp_data_pad
            assign rsp_data = {{(DLEN-32){1'b0}}, sft_data[31:0]};
        end
        else begin: gen_rsp_data
            assign rsp_data = sft_data[31:0];
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rsp_vld_r  <= 1'b0;
            rsp_data_r <= {DLEN{1'b0}};
        end
        else begin
            if (rom_req_vld & rom_req_rdy) begin
                rsp_vld_r  <= #UDLY 1'b1;
                rsp_data_r <= #UDLY rsp_data;
            end
            else if (rom_rsp_vld & rom_rsp_rdy) begin
                rsp_vld_r  <= #UDLY 1'b0;
            end
        end
    end
    
    uv_rom_logic
    #(
        .ROM_AW                     ( ROM_AW            )
    )
    u_rom_logic
    (
        .clk                        ( clk               ),
        .rst_n                      ( rst_n             ),

        .rom_addr                   ( rom_addr          ),
        .rom_data                   ( rom_data          )
    );

endmodule

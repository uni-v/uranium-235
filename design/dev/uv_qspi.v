//************************************************************
// See LICENSE for license details.
//
// Module: uv_qspi
//
// Designer: Owen
//
// Description:
//      FIXME: Quad-SPI to be implemented.
//      Compatible with Dual-SPI and standard SPI.
//************************************************************

`timescale 1ns / 1ps

module uv_qspi
#(
    parameter ALEN                  = 12,
    parameter DLEN                  = 32,
    parameter MLEN                  = DLEN / 8
)
(
    input                           clk,
    input                           rst_n,

    input                           qspi_req_vld,
    output                          qspi_req_rdy,
    input                           qspi_req_read,
    input  [ALEN-1:0]               qspi_req_addr,
    input  [MLEN-1:0]               qspi_req_mask,
    input  [DLEN-1:0]               qspi_req_data,

    output                          qspi_rsp_vld,
    input                           qspi_rsp_rdy,
    output [1:0]                    qspi_rsp_excp,
    output [DLEN-1:0]               qspi_rsp_data,

    output                          spi_sck,
    output                          spi_cs0,
    output                          spi_cs1,
    output                          spi_cs2,
    output                          spi_cs3,
    output                          spi_oen0,
    output                          spi_oen1,
    output                          spi_oen2,
    output                          spi_oen3,
    output                          spi_sdo0,
    output                          spi_sdo1,
    output                          spi_sdo2,
    output                          spi_sdo3,
    input                           spi_sdi0,
    input                           spi_sdi1,
    input                           spi_sdi2,
    input                           spi_sdi3,

    output                          spi_irq
);

    localparam UDLY = 1;

    reg                             rsp_vld_r;

    assign qspi_req_rdy             = 1'b1;
    assign qspi_rsp_vld             = rsp_vld_r;
    assign qspi_rsp_excp            = 2'b0;
    assign qspi_rsp_data            = {DLEN{1'b1}};

    assign spi_sck                  = 1'b1;
    assign spi_cs0                  = 1'b1;
    assign spi_cs1                  = 1'b1;
    assign spi_cs2                  = 1'b1;
    assign spi_cs3                  = 1'b1;
    assign spi_oen0                 = 1'b1;
    assign spi_oen1                 = 1'b1;
    assign spi_oen2                 = 1'b1;
    assign spi_oen3                 = 1'b1;
    assign spi_sdo0                 = 1'b1;
    assign spi_sdo1                 = 1'b1;
    assign spi_sdo2                 = 1'b1;
    assign spi_sdo3                 = 1'b1;
    assign spi_irq                  = 1'b0;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rsp_vld_r <= 1'b0;
        end
        else begin
            if (qspi_req_vld & qspi_req_rdy) begin
                rsp_vld_r <= #UDLY 1'b1;
            end
            else if (qspi_rsp_vld & qspi_rsp_rdy) begin
                rsp_vld_r <= #UDLY 1'b0;
            end
        end
    end

endmodule

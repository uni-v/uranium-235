//************************************************************
// See LICENSE for license details.
//
// Module: uv_iomux
//
// Designer: Owen
//
// Description:
//      IO Mux to reuse IO ports for GPIO & other perips.
//************************************************************

`timescale 1ns / 1ps

module uv_iomux
#(
    parameter IO_NUM                = 32,
    parameter MUX_IO_NUM            = 10
)
(
    input                           clk,
    input                           rst_n,

    input                           gpio_mode,

    output                          uart_rx,
    input                           uart_tx,

    input                           spi0_cs,
    input                           spi0_sck,
    input                           spi0_mosi,
    output                          spi0_miso,

    input                           spi1_cs,
    input                           spi1_sck,
    input                           spi1_mosi,
    output                          spi1_miso,

    input  [IO_NUM-1:0]             src_gpio_pu,
    input  [IO_NUM-1:0]             src_gpio_pd,
    input  [IO_NUM-1:0]             src_gpio_ie,
    output [IO_NUM-1:0]             src_gpio_in,
    input  [IO_NUM-1:0]             src_gpio_oe,
    input  [IO_NUM-1:0]             src_gpio_out,

    output [IO_NUM-1:0]             dst_gpio_pu,
    output [IO_NUM-1:0]             dst_gpio_pd,
    output [IO_NUM-1:0]             dst_gpio_ie,
    input  [IO_NUM-1:0]             dst_gpio_in,
    output [IO_NUM-1:0]             dst_gpio_oe,
    output [IO_NUM-1:0]             dst_gpio_out
);

    // Mux for UART.
    assign dst_gpio_pu [0]          = gpio_mode ? src_gpio_pu [0] : 1'b1;   // Pull-up for uart_rx.
    assign dst_gpio_pd [0]          = gpio_mode ? src_gpio_pd [0] : 1'b0;
    assign dst_gpio_ie [0]          = gpio_mode ? src_gpio_ie [0] : 1'b1;   // Input for uart_rx.
    assign dst_gpio_oe [0]          = gpio_mode ? src_gpio_oe [0] : 1'b0;
    assign dst_gpio_out[0]          = gpio_mode ? src_gpio_out[0] : 1'b0;
    assign src_gpio_in [0]          = gpio_mode ? dst_gpio_in [0] : 1'b0;
    assign uart_rx                  = gpio_mode ? 1'b1 : dst_gpio_in[0];

    assign dst_gpio_pu [1]          = gpio_mode ? src_gpio_pu [1] : 1'b0;
    assign dst_gpio_pd [1]          = gpio_mode ? src_gpio_pd [1] : 1'b0;
    assign dst_gpio_ie [1]          = gpio_mode ? src_gpio_ie [1] : 1'b0;
    assign dst_gpio_oe [1]          = gpio_mode ? src_gpio_oe [1] : 1'b1;   // Output for uart_tx.
    assign dst_gpio_out[1]          = gpio_mode ? src_gpio_out[1] : uart_tx;
    assign src_gpio_in [1]          = gpio_mode ? dst_gpio_in [1] : 1'b0;

    // Mux for SPI0.
    assign dst_gpio_pu [2]          = gpio_mode ? src_gpio_pu [2] : 1'b0;
    assign dst_gpio_pd [2]          = gpio_mode ? src_gpio_pd [2] : 1'b0;
    assign dst_gpio_ie [2]          = gpio_mode ? src_gpio_ie [2] : 1'b0;
    assign dst_gpio_oe [2]          = gpio_mode ? src_gpio_oe [2] : 1'b1;   // Output for spi0_cs.
    assign dst_gpio_out[2]          = gpio_mode ? src_gpio_out[2] : spi0_cs;
    assign src_gpio_in [2]          = gpio_mode ? dst_gpio_in [2] : 1'b0;

    assign dst_gpio_pu [3]          = gpio_mode ? src_gpio_pu [3] : 1'b0;
    assign dst_gpio_pd [3]          = gpio_mode ? src_gpio_pd [3] : 1'b0;
    assign dst_gpio_ie [3]          = gpio_mode ? src_gpio_ie [3] : 1'b0;
    assign dst_gpio_oe [3]          = gpio_mode ? src_gpio_oe [3] : 1'b1;   // Output for spi0_sck.
    assign dst_gpio_out[3]          = gpio_mode ? src_gpio_out[3] : spi0_sck;
    assign src_gpio_in [3]          = gpio_mode ? dst_gpio_in [3] : 1'b0;

    assign dst_gpio_pu [4]          = gpio_mode ? src_gpio_pu [4] : 1'b0;
    assign dst_gpio_pd [4]          = gpio_mode ? src_gpio_pd [4] : 1'b0;
    assign dst_gpio_ie [4]          = gpio_mode ? src_gpio_ie [4] : 1'b0;
    assign dst_gpio_oe [4]          = gpio_mode ? src_gpio_oe [4] : 1'b1;   // Output for spi0_mosi.
    assign dst_gpio_out[4]          = gpio_mode ? src_gpio_out[4] : spi0_mosi;
    assign src_gpio_in [4]          = gpio_mode ? dst_gpio_in [4] : 1'b0;

    assign dst_gpio_pu [5]          = gpio_mode ? src_gpio_pu [5] : 1'b1;
    assign dst_gpio_pd [5]          = gpio_mode ? src_gpio_pd [5] : 1'b0;
    assign dst_gpio_ie [5]          = gpio_mode ? src_gpio_ie [5] : 1'b1;   // Input for spi0_miso.
    assign dst_gpio_oe [5]          = gpio_mode ? src_gpio_oe [5] : 1'b0;
    assign dst_gpio_out[5]          = gpio_mode ? src_gpio_out[5] : 1'b0;
    assign src_gpio_in [5]          = gpio_mode ? dst_gpio_in [5] : 1'b0;
    assign spi0_miso                = gpio_mode ? 1'b0 : dst_gpio_in [5];

    // Mux for SPI1.
    assign dst_gpio_pu [6]          = gpio_mode ? src_gpio_pu [6] : 1'b0;
    assign dst_gpio_pd [6]          = gpio_mode ? src_gpio_pd [6] : 1'b0;
    assign dst_gpio_ie [6]          = gpio_mode ? src_gpio_ie [6] : 1'b0;
    assign dst_gpio_oe [6]          = gpio_mode ? src_gpio_oe [6] : 1'b1;   // Output for spi1_cs.
    assign dst_gpio_out[6]          = gpio_mode ? src_gpio_out[6] : spi1_cs;
    assign src_gpio_in [6]          = gpio_mode ? dst_gpio_in [6] : 1'b0;

    assign dst_gpio_pu [7]          = gpio_mode ? src_gpio_pu [7] : 1'b0;
    assign dst_gpio_pd [7]          = gpio_mode ? src_gpio_pd [7] : 1'b0;
    assign dst_gpio_ie [7]          = gpio_mode ? src_gpio_ie [7] : 1'b0;
    assign dst_gpio_oe [7]          = gpio_mode ? src_gpio_oe [7] : 1'b1;   // Output for spi1_sck.
    assign dst_gpio_out[7]          = gpio_mode ? src_gpio_out[7] : spi1_sck;
    assign src_gpio_in [7]          = gpio_mode ? dst_gpio_in [7] : 1'b0;

    assign dst_gpio_pu [8]          = gpio_mode ? src_gpio_pu [8] : 1'b0;
    assign dst_gpio_pd [8]          = gpio_mode ? src_gpio_pd [8] : 1'b0;
    assign dst_gpio_ie [8]          = gpio_mode ? src_gpio_ie [8] : 1'b0;
    assign dst_gpio_oe [8]          = gpio_mode ? src_gpio_oe [8] : 1'b1;   // Output for spi1_mosi.
    assign dst_gpio_out[8]          = gpio_mode ? src_gpio_out[8] : spi1_mosi;
    assign src_gpio_in [8]          = gpio_mode ? dst_gpio_in [8] : 1'b0;

    assign dst_gpio_pu [9]          = gpio_mode ? src_gpio_pu [9] : 1'b1;
    assign dst_gpio_pd [9]          = gpio_mode ? src_gpio_pd [9] : 1'b0;
    assign dst_gpio_ie [9]          = gpio_mode ? src_gpio_ie [9] : 1'b1;   // Input for spi1_miso.
    assign dst_gpio_oe [9]          = gpio_mode ? src_gpio_oe [9] : 1'b0;
    assign dst_gpio_out[9]          = gpio_mode ? src_gpio_out[9] : 1'b0;
    assign src_gpio_in [9]          = gpio_mode ? dst_gpio_in [9] : 1'b0;
    assign spi1_miso                = gpio_mode ? 1'b0 : dst_gpio_in [9];

    // Pass through other GPIOs.
    generate
        if (IO_NUM > MUX_IO_NUM) begin: gen_other_gpio
            assign dst_gpio_pu [IO_NUM-1:MUX_IO_NUM] = src_gpio_pu [IO_NUM-1:MUX_IO_NUM];
            assign dst_gpio_pd [IO_NUM-1:MUX_IO_NUM] = src_gpio_pd [IO_NUM-1:MUX_IO_NUM];
            assign dst_gpio_ie [IO_NUM-1:MUX_IO_NUM] = src_gpio_ie [IO_NUM-1:MUX_IO_NUM];
            assign dst_gpio_oe [IO_NUM-1:MUX_IO_NUM] = src_gpio_oe [IO_NUM-1:MUX_IO_NUM];
            assign dst_gpio_out[IO_NUM-1:MUX_IO_NUM] = src_gpio_out[IO_NUM-1:MUX_IO_NUM];
            assign src_gpio_in [IO_NUM-1:MUX_IO_NUM] = dst_gpio_in [IO_NUM-1:MUX_IO_NUM];
        end
    endgenerate

endmodule

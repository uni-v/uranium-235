//************************************************************
// See LICENSE for license details.
//
// Module: uv_iob
//
// Designer: Owen
//
// Description:
//      IO bridge.
//************************************************************

`timescale 1ns / 1ps

module uv_iob
#(
    parameter IO_NUM            = 32
)
(
    // From IO.
    input                       io_ext_clk,
`ifdef USE_LOW_CLK
    input                       io_low_clk,
`endif
    input                       io_btn_rst_n,

`ifdef USE_EXT_MEM
    // TODO.
`endif

`ifdef HAS_JTAG
    input                       io_jtag_tck,
    input                       io_jtag_tms,
    input                       io_jtag_tdi,
    output                      io_jtag_tdo,
`endif

`ifdef HAS_I2C
    inout                       io_i2c_scl,
    inout                       io_i2c_sda,
`endif

    inout  [IO_NUM-1:0]         io_gpio,

    // To Internal.
    output                      ext_clk,
`ifdef USE_LOW_CLK
    output                      low_clk,
`endif
    output                      btn_rst_n,

`ifdef HAS_JTAG
    output                      jtag_tck,
    output                      jtag_tms,
    output                      jtag_tdi,
    input                       jtag_tdo,
`endif

`ifdef HAS_I2C
    output                      i2c_scl_in,
    input                       i2c_scl_out,
    input                       i2c_scl_oen,
    output                      i2c_sda_in,
    input                       i2c_sda_out,
    input                       i2c_sda_oen,
`endif

    input  [IO_NUM-1:0]         gpio_pu,
    input  [IO_NUM-1:0]         gpio_pd,
    input  [IO_NUM-1:0]         gpio_ie,
    output [IO_NUM-1:0]         gpio_in,
    input  [IO_NUM-1:0]         gpio_oe,
    input  [IO_NUM-1:0]         gpio_out
);

    genvar i;

`ifdef ASIC

    // Pad instantiation for specific process.

`elsif FPGA

    assign ext_clk              = io_ext_clk;
`ifdef USE_LOW_CLK
    assign low_clk              = io_low_clk;
`endif
    assign btn_rst_n            = io_btn_rst_n;

    wire [IO_NUM-1:0]           iobuf_out;
    generate
        for (i = 0; i < IO_NUM; i = i + 1) begin: gen_gpio_pad
            IOBUF
            #(
                .DRIVE          ( 12                ),  // Specify the output drive strength
                .IBUF_LOW_PWR   ( "TRUE"            ),  // Low Power - "TRUE", High Performance = "FALSE"
                .IOSTANDARD     ( "DEFAULT"         ),  // Specify the I/O standard
                .SLEW           ( "SLOW"            )   // Specify the output slew rate
            )
            IOBUF_gpio
            (
                .O              ( iobuf_out[i]      ),  // 1-bit output: Buffer output
                .I              ( gpio_out[i]       ),  // 1-bit input: Buffer input
                .IO             ( io_gpio[i]        ),  // 1-bit inout: Buffer inout (connect directly to top-level port)
                .T              ( ~gpio_oe[i]       )   // 1-bit input: 3-state enable input
            );
            assign gpio_in[i]   = iobuf_out[i] & gpio_ie[i];
        end
    endgenerate

`else // SIMULATION

    assign ext_clk              = io_ext_clk;
`ifdef USE_LOW_CLK
    assign low_clk              = io_low_clk;
`endif
    assign btn_rst_n            = io_btn_rst_n;

`ifdef HAS_JTAG
    assign jtag_tck             = io_jtag_tck;
    assign jtag_tms             = io_jtag_tms;
    assign jtag_tdi             = io_jtag_tdi;
    assign io_jtag_tdo          = jtag_tdo;
`endif

`ifdef HAS_I2C
    assign i2c_scl_in           = io_i2c_scl;
    assign io_i2c_scl           = ~i2c_scl_oen ? i2c_scl_out : 1'bz;
    assign i2c_sda_in           = io_i2c_sda;
    assign io_i2c_sda           = ~i2c_sda_oen ? i2c_sda_out : 1'bz;
`endif

    generate
        for (i = 0; i < IO_NUM; i = i + 1) begin: gen_gpio_pad
            assign gpio_in[i]   = gpio_ie[i] ? io_gpio[i]
                                : gpio_pu[i] ? 1'b1
                                : gpio_pd[i] ? 1'b0
                                : 1'bz;

            assign io_gpio[i]   = gpio_oe[i] ? gpio_out[i]
                                : 1'bz;
        end
    endgenerate

`endif

endmodule

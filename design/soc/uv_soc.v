//************************************************************
// See LICENSE for license details.
//
// Module: uv_soc
//
// Designer: Owen
//
// Description:
//      The top SOC module.
//************************************************************

`timescale 1ns / 1ps

module uv_soc
#(
    parameter IO_NUM            = 32
)
(
    input                       io_ext_clk,
`ifdef USE_LOW_CLK
    input                       io_low_clk,
`endif
    input                       io_btn_rst_n,

`ifdef USE_EXT_MEM
    // TODO.
`endif

`ifdef HAS_JTAG
    // JTAG.
    input                       io_jtag_tck,
    input                       io_jtag_tms,
    input                       io_jtag_tdi,
    output                      io_jtag_tdo,
`endif

`ifdef HAS_I2C
    // I2C (OD)
    inout                       io_i2c_scl,
    inout                       io_i2c_sda,
`endif

    // GPIO (reused for SPI, UART, etc.)
    inout  [IO_NUM-1:0]         io_gpio
);

    localparam UDLY             = 1;

    wire                        clk_locked;
    wire                        ext_clk;
    wire                        low_clk;
    wire                        sys_clk;

    wire                        asyn_btn_rst_n;
    wire                        asyn_por_rst_n;
    wire                        btn_rst_n;
    wire                        por_rst_n;
    wire                        sys_rst_n;

`ifdef HAS_JTAG
    wire                        jtag_tck;
    wire                        jtag_tms;
    wire                        jtag_tdi;
    wire                        jtag_tdo;
`endif

`ifdef HAS_I2C
    wire                        i2c_scl_in;
    wire                        i2c_scl_out;
    wire                        i2c_scl_oen;
    wire                        i2c_sda_in;
    wire                        i2c_sda_out;
    wire                        i2c_sda_oen;
`endif

    wire [IO_NUM-1:0]           gpio_pu;
    wire [IO_NUM-1:0]           gpio_pd;
    wire [IO_NUM-1:0]           gpio_ie;
    wire [IO_NUM-1:0]           gpio_in;
    wire [IO_NUM-1:0]           gpio_oe;
    wire [IO_NUM-1:0]           gpio_out;

    /************************************************
     * System.
     ************************************************/
    uv_sys
    #(
        .IO_NUM                 ( IO_NUM            )
    )
    u_sys
    (
        .sys_clk                ( sys_clk           ),
        .low_clk                ( low_clk           ),
        .sys_rst_n              ( sys_rst_n         ),
        .por_rst_n              ( por_rst_n         ),

    `ifdef HAS_JTAG
        .jtag_tck               ( jtag_tck          ),
        .jtag_tms               ( jtag_tms          ),
        .jtag_tdi               ( jtag_tdi          ),
        .jtag_tdo               ( jtag_tdo          ),
    `else
        .jtag_tck               ( 1'b1              ),
        .jtag_tms               ( 1'b1              ),
        .jtag_tdi               ( 1'b1              ),
        .jtag_tdo               (                   ),
    `endif

    `ifdef HAS_I2C
        .i2c_scl_in             ( i2c_scl_in        ),
        .i2c_scl_out            ( i2c_scl_out       ),
        .i2c_scl_oen            ( i2c_scl_oen       ),
        .i2c_sda_in             ( i2c_sda_in        ),
        .i2c_sda_out            ( i2c_sda_out       ),
        .i2c_sda_oen            ( i2c_sda_oen       ),
    `else
        .i2c_scl_in             ( 1'b0              ),
        .i2c_scl_out            (                   ),
        .i2c_scl_oen            (                   ),
        .i2c_sda_in             ( 1'b0              ),
        .i2c_sda_out            (                   ),
        .i2c_sda_oen            (                   ),
    `endif

        .gpio_pu                ( gpio_pu           ),
        .gpio_pd                ( gpio_pd           ),
        .gpio_ie                ( gpio_ie           ),
        .gpio_in                ( gpio_in           ),
        .gpio_oe                ( gpio_oe           ),
        .gpio_out               ( gpio_out          )
    );

    /************************************************
     * Reset.
     ************************************************/
    // Syncronize button reset.
    assign asyn_rst_n           = asyn_btn_rst_n & (~clk_locked);

    uv_rst_sync
    #(
        .SYNC_STAGE             ( 2                 )
    )
    u_btn_rst_sync
    (
        .clk                    ( sys_clk           ),
        .rst_n                  ( asyn_rst_n        ),
        .sync_rst_n             ( sys_rst_n         )
    );

    // Syncronize power-on reset.
    uv_rst_sync
    #(
        .SYNC_STAGE             ( 2                 )
    )
    u_por_rst_sync
    (
        .clk                    ( sys_clk           ),
        .rst_n                  ( asyn_por_rst_n    ),
        .sync_rst_n             ( por_rst_n         )
    );

    /************************************************
     * Clock.
     ************************************************/
    // Clock divider & selector.
    // FIXME: Only use external clock now!
`ifdef ASIC
    
    // assign clk_locked        = 1'b0;

`elsif FPGA

    wire ext_clk_locked;
    uv_fpga_clk_wiz_ext u_mmcm_ext
    (
        // Clock out ports
        .clk_out1               ( sys_clk           ),  // output clk_out1
        // Status and control signals
        .reset                  ( sys_rst_n         ),  // input reset
        .locked                 ( ext_clk_locked    ),  // output locked
        // Clock in ports
        .clk_in1                ( io_ext_clk        )   // input clk_in1
    );

`ifdef USE_LOW_CLK
    wire low_clk_locked;
    uv_fpga_clk_wiz_low u_mmcm_low
    (
        // Clock out ports
        .clk_out1               ( low_clk           ),  // output clk_out1
        // Status and control signals
        .reset                  ( sys_rst_n         ),  // input reset
        .locked                 ( low_clk_locked    ),  // output locked
        // Clock in ports
        .clk_in1                ( io_low_clk        )   // input clk_in1
    );
    assign clk_locked           = ext_clk_locked | low_clk_locked;
`else
    assign clk_locked           = ext_clk_locked;
    assign low_clk              = sys_clk;
`endif

`else

    assign clk_locked           = 1'b0;
    assign sys_clk              = ext_clk;

    `ifndef USE_LOW_CLK
        assign low_clk          = ext_clk;
    `endif

`endif

    /************************************************
     * LDO.
     ************************************************/
    uv_ldo u_ldo
    (
        .clk                    ( sys_clk           ),
        .rst_n                  ( sys_rst_n         ),
        .por_rst_n              ( asyn_por_rst_n    )
    );

    /************************************************
     * IOB.
     ************************************************/
    uv_iob
    #(
        .IO_NUM                 ( IO_NUM            )
    )
    u_iob
    (
        .io_ext_clk             ( io_ext_clk        ),
    `ifdef USE_LOW_CLK
        .io_low_clk             ( io_low_clk        ),
    `endif
        .io_btn_rst_n           ( io_btn_rst_n      ),

    `ifdef USE_EXT_MEM
        // TODO.
    `endif

    `ifdef HAS_JTAG
        .io_jtag_tck            ( io_jtag_tck       ),
        .io_jtag_tms            ( io_jtag_tms       ),
        .io_jtag_tdi            ( io_jtag_tdi       ),
        .io_jtag_tdo            ( io_jtag_tdo       ),
    `endif

    `ifdef HAS_I2C
        .io_i2c_scl             ( io_i2c_scl        ),
        .io_i2c_sda             ( io_i2c_sda        ),
    `endif

        .io_gpio                ( io_gpio           ),

        .ext_clk                ( ext_clk           ),
    `ifdef USE_LOW_CLK
        .low_clk                ( low_clk           ),
    `endif
        .btn_rst_n              ( asyn_btn_rst_n    ),

    `ifdef HAS_JTAG
        .jtag_tck               ( jtag_tck          ),
        .jtag_tms               ( jtag_tms          ),
        .jtag_tdi               ( jtag_tdi          ),
        .jtag_tdo               ( jtag_tdo          ),
    `endif

    `ifdef HAS_I2C
        .i2c_scl_in             ( i2c_scl_in        ),
        .i2c_scl_out            ( i2c_scl_out       ),
        .i2c_scl_oen            ( i2c_scl_oen       ),
        .i2c_sda_in             ( i2c_sda_in        ),
        .i2c_sda_out            ( i2c_sda_out       ),
        .i2c_sda_oen            ( i2c_sda_oen       ),
    `endif

        .gpio_pu                ( gpio_pu           ),
        .gpio_pd                ( gpio_pd           ),
        .gpio_ie                ( gpio_ie           ),
        .gpio_in                ( gpio_in           ),
        .gpio_oe                ( gpio_oe           ),
        .gpio_out               ( gpio_out          )
    );

endmodule

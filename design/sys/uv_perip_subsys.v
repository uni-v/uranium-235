//************************************************************
// See LICENSE for license details.
//
// Module: uv_perip_subsys
//
// Designer: Owen
//
// Description:
//      Peripheral Subsystem.
//************************************************************

`timescale 1ns / 1ps

module uv_perip_subsys
#(
    parameter ALEN                  = 16,
    parameter DLEN                  = 32,
    parameter MLEN                  = DLEN / 8,
    parameter IO_NUM                = 32
)
(
    input                           clk,
    input                           rst_n,
    input                           low_clk,

    input                           perip_req_vld,
    output                          perip_req_rdy,
    input                           perip_req_read,
    input  [ALEN-1:0]               perip_req_addr,
    input  [MLEN-1:0]               perip_req_mask,
    input  [DLEN-1:0]               perip_req_data,

    output                          perip_rsp_vld,
    input                           perip_rsp_rdy,
    output [1:0]                    perip_rsp_excp,
    output [DLEN-1:0]               perip_rsp_data,

    input                           jtag_tck,
    input                           jtag_tms,
    input                           jtag_tdi,
    output                          jtag_tdo,

    input                           i2c_scl_in,
    output                          i2c_scl_out,
    output                          i2c_scl_oen,
    input                           i2c_sda_in,
    output                          i2c_sda_out,
    output                          i2c_sda_oen,
    
    input                           gpio_mode,
    output [IO_NUM+7:0]             perip_irq,
    output                          wdt_rst_n,

    output [IO_NUM-1:0]             gpio_pu,
    output [IO_NUM-1:0]             gpio_pd,
    output [IO_NUM-1:0]             gpio_ie,
    input  [IO_NUM-1:0]             gpio_in,
    output [IO_NUM-1:0]             gpio_oe,
    output [IO_NUM-1:0]             gpio_out
);

    localparam UDLY                 = 1;
    localparam MUX_IO_NUM           = 10;

    localparam GPIO_BASE_LSB        = 12;
    localparam GPIO_BASE_ADDR       = 4'h0;
    localparam UART_BASE_LSB        = 12;
    localparam UART_BASE_ADDR       = 4'h1;
    localparam I2C_BASE_LSB         = 12;
    localparam I2C_BASE_ADDR        = 4'h2;
    localparam SPI0_BASE_LSB        = 12;
    localparam SPI0_BASE_ADDR       = 4'h3;
    localparam SPI1_BASE_LSB        = 12;
    localparam SPI1_BASE_ADDR       = 4'h4;
    localparam TMR_BASE_LSB         = 12;
    localparam TMR_BASE_ADDR        = 4'h5;
    localparam WDT_BASE_LSB         = 12;
    localparam WDT_BASE_ADDR        = 4'h6;
    localparam DBG_BASE_LSB         = 12;
    localparam DBG_BASE_ADDR        = 4'h7;
    
    wire [7:0]                      bus_slv_dev_vld;

    wire                            gpio_req_vld;
    wire                            gpio_req_rdy;
    wire                            gpio_req_read;
    wire [ALEN-1:0]                 gpio_req_addr;
    wire [MLEN-1:0]                 gpio_req_mask;
    wire [DLEN-1:0]                 gpio_req_data;
    wire                            gpio_rsp_vld;
    wire                            gpio_rsp_rdy;
    wire [1:0]                      gpio_rsp_excp;
    wire [DLEN-1:0]                 gpio_rsp_data;
    wire [GPIO_BASE_LSB-1:0]        gpio_req_offset;

    wire                            uart_req_vld;
    wire                            uart_req_rdy;
    wire                            uart_req_read;
    wire [ALEN-1:0]                 uart_req_addr;
    wire [MLEN-1:0]                 uart_req_mask;
    wire [DLEN-1:0]                 uart_req_data;
    wire                            uart_rsp_vld;
    wire                            uart_rsp_rdy;
    wire [1:0]                      uart_rsp_excp;
    wire [DLEN-1:0]                 uart_rsp_data;
    wire [UART_BASE_LSB-1:0]        uart_req_offset;

    wire                            i2c_req_vld;
    wire                            i2c_req_rdy;
    wire                            i2c_req_read;
    wire [ALEN-1:0]                 i2c_req_addr;
    wire [MLEN-1:0]                 i2c_req_mask;
    wire [DLEN-1:0]                 i2c_req_data;
    wire                            i2c_rsp_vld;
    wire                            i2c_rsp_rdy;
    wire [1:0]                      i2c_rsp_excp;
    wire [DLEN-1:0]                 i2c_rsp_data;
    wire [I2C_BASE_LSB-1:0]         i2c_req_offset;

    wire                            spi0_req_vld;
    wire                            spi0_req_rdy;
    wire                            spi0_req_read;
    wire [ALEN-1:0]                 spi0_req_addr;
    wire [MLEN-1:0]                 spi0_req_mask;
    wire [DLEN-1:0]                 spi0_req_data;
    wire                            spi0_rsp_vld;
    wire                            spi0_rsp_rdy;
    wire [1:0]                      spi0_rsp_excp;
    wire [DLEN-1:0]                 spi0_rsp_data;
    wire [SPI0_BASE_LSB-1:0]        spi0_req_offset;

    wire                            spi1_req_vld;
    wire                            spi1_req_rdy;
    wire                            spi1_req_read;
    wire [ALEN-1:0]                 spi1_req_addr;
    wire [MLEN-1:0]                 spi1_req_mask;
    wire [DLEN-1:0]                 spi1_req_data;
    wire                            spi1_rsp_vld;
    wire                            spi1_rsp_rdy;
    wire [1:0]                      spi1_rsp_excp;
    wire [DLEN-1:0]                 spi1_rsp_data;
    wire [SPI1_BASE_LSB-1:0]        spi1_req_offset;

    wire                            tmr_req_vld;
    wire                            tmr_req_rdy;
    wire                            tmr_req_read;
    wire [ALEN-1:0]                 tmr_req_addr;
    wire [MLEN-1:0]                 tmr_req_mask;
    wire [DLEN-1:0]                 tmr_req_data;
    wire                            tmr_rsp_vld;
    wire                            tmr_rsp_rdy;
    wire [1:0]                      tmr_rsp_excp;
    wire [DLEN-1:0]                 tmr_rsp_data;
    wire [TMR_BASE_LSB-1:0]         tmr_req_offset;

    wire                            wdt_req_vld;
    wire                            wdt_req_rdy;
    wire                            wdt_req_read;
    wire [ALEN-1:0]                 wdt_req_addr;
    wire [MLEN-1:0]                 wdt_req_mask;
    wire [DLEN-1:0]                 wdt_req_data;
    wire                            wdt_rsp_vld;
    wire                            wdt_rsp_rdy;
    wire [1:0]                      wdt_rsp_excp;
    wire [DLEN-1:0]                 wdt_rsp_data;
    wire [WDT_BASE_LSB-1:0]         wdt_req_offset;

    wire                            dbg_req_vld;
    wire                            dbg_req_rdy;
    wire                            dbg_req_read;
    wire [ALEN-1:0]                 dbg_req_addr;
    wire [MLEN-1:0]                 dbg_req_mask;
    wire [DLEN-1:0]                 dbg_req_data;
    wire                            dbg_rsp_vld;
    wire                            dbg_rsp_rdy;
    wire [1:0]                      dbg_rsp_excp;
    wire [DLEN-1:0]                 dbg_rsp_data;
    wire [DBG_BASE_LSB-1:0]         dbg_req_offset;

    wire [IO_NUM-1:0]               dev_gpio_pu;
    wire [IO_NUM-1:0]               dev_gpio_pd;
    wire [IO_NUM-1:0]               dev_gpio_ie;
    wire [IO_NUM-1:0]               dev_gpio_in;
    wire [IO_NUM-1:0]               dev_gpio_oe;
    wire [IO_NUM-1:0]               dev_gpio_out;

    wire                            uart_rx;
    wire                            uart_tx;

    wire                            spi0_cs;
    wire                            spi0_sck;
    wire                            spi0_mosi;
    wire                            spi0_miso;

    wire                            spi1_cs;
    wire                            spi1_sck;
    wire                            spi1_mosi;
    wire                            spi1_miso;

    wire [IO_NUM-1:0]               gpio_irq;
    wire                            uart_irq;
    wire                            spi0_irq;
    wire                            spi1_irq;
    wire                            i2c_irq;
    wire                            tmr_irq;
    wire                            wdt_irq;
    wire                            tmr_evt;

    assign perip_irq[0]             = uart_irq;
    assign perip_irq[1]             = spi0_irq;
    assign perip_irq[2]             = spi1_irq;
    assign perip_irq[3]             = i2c_irq;
    assign perip_irq[4]             = tmr_irq;
    assign perip_irq[5]             = wdt_irq;
    assign perip_irq[6]             = 1'b0;
    assign perip_irq[7]             = 1'b0;
    assign perip_irq[IO_NUM+7:8]    = gpio_irq;

    assign gpio_req_offset          = gpio_req_addr[GPIO_BASE_LSB-1:0];
    assign uart_req_offset          = uart_req_addr[UART_BASE_LSB-1:0];
    assign spi0_req_offset          = spi0_req_addr[SPI0_BASE_LSB-1:0];
    assign spi1_req_offset          = spi1_req_addr[SPI1_BASE_LSB-1:0];
    assign tmr_req_offset           = tmr_req_addr[TMR_BASE_LSB-1:0];
    assign wdt_req_offset           = wdt_req_addr[WDT_BASE_LSB-1:0];
    assign i2c_req_offset           = i2c_req_addr[I2C_BASE_LSB-1:0];
    assign dbg_req_offset           = dbg_req_addr[DBG_BASE_LSB-1:0];

    // Bus Bridge.
    assign bus_slv_dev_vld          = 8'hFF;

    uv_bus_fab_1x8
    #(
        .ALEN                       ( ALEN                  ),
        .DLEN                       ( DLEN                  ),
        .MLEN                       ( MLEN                  ),
        .SLV0_BASE_LSB              ( GPIO_BASE_LSB         ),
        .SLV0_BASE_ADDR             ( GPIO_BASE_ADDR        ),
        .SLV1_BASE_LSB              ( UART_BASE_LSB         ),
        .SLV1_BASE_ADDR             ( UART_BASE_ADDR        ),
        .SLV2_BASE_LSB              ( I2C_BASE_LSB          ),
        .SLV2_BASE_ADDR             ( I2C_BASE_ADDR         ),
        .SLV3_BASE_LSB              ( SPI0_BASE_LSB         ),
        .SLV3_BASE_ADDR             ( SPI0_BASE_ADDR        ),
        .SLV4_BASE_LSB              ( SPI1_BASE_LSB         ),
        .SLV4_BASE_ADDR             ( SPI1_BASE_ADDR        ),
        .SLV5_BASE_LSB              ( TMR_BASE_LSB          ),
        .SLV5_BASE_ADDR             ( TMR_BASE_ADDR         ),
        .SLV6_BASE_LSB              ( WDT_BASE_LSB          ),
        .SLV6_BASE_ADDR             ( WDT_BASE_ADDR         ),
        .SLV7_BASE_LSB              ( DBG_BASE_LSB          ),
        .SLV7_BASE_ADDR             ( DBG_BASE_ADDR         )
    )
    u_perip_bridge
    (
        .clk                        ( clk                   ),
        .rst_n                      ( rst_n                 ),

        // Device enabling.
        .slv_dev_vld                ( bus_slv_dev_vld       ),

        // Master.
        .mst_req_vld                ( perip_req_vld         ),
        .mst_req_rdy                ( perip_req_rdy         ),
        .mst_req_read               ( perip_req_read        ),
        .mst_req_addr               ( perip_req_addr        ),
        .mst_req_mask               ( perip_req_mask        ),
        .mst_req_data               ( perip_req_data        ),
        .mst_rsp_vld                ( perip_rsp_vld         ),
        .mst_rsp_rdy                ( perip_rsp_rdy         ),
        .mst_rsp_excp               ( perip_rsp_excp        ),
        .mst_rsp_data               ( perip_rsp_data        ),

        // Slaves.
        .slv0_req_vld               ( gpio_req_vld          ),
        .slv0_req_rdy               ( gpio_req_rdy          ),
        .slv0_req_read              ( gpio_req_read         ),
        .slv0_req_addr              ( gpio_req_addr         ),
        .slv0_req_mask              ( gpio_req_mask         ),
        .slv0_req_data              ( gpio_req_data         ),
        .slv0_rsp_vld               ( gpio_rsp_vld          ),
        .slv0_rsp_rdy               ( gpio_rsp_rdy          ),
        .slv0_rsp_excp              ( gpio_rsp_excp         ),
        .slv0_rsp_data              ( gpio_rsp_data         ),

        .slv1_req_vld               ( uart_req_vld          ),
        .slv1_req_rdy               ( uart_req_rdy          ),
        .slv1_req_read              ( uart_req_read         ),
        .slv1_req_addr              ( uart_req_addr         ),
        .slv1_req_mask              ( uart_req_mask         ),
        .slv1_req_data              ( uart_req_data         ),
        .slv1_rsp_vld               ( uart_rsp_vld          ),
        .slv1_rsp_rdy               ( uart_rsp_rdy          ),
        .slv1_rsp_excp              ( uart_rsp_excp         ),
        .slv1_rsp_data              ( uart_rsp_data         ),

        .slv2_req_vld               ( i2c_req_vld           ),
        .slv2_req_rdy               ( i2c_req_rdy           ),
        .slv2_req_read              ( i2c_req_read          ),
        .slv2_req_addr              ( i2c_req_addr          ),
        .slv2_req_mask              ( i2c_req_mask          ),
        .slv2_req_data              ( i2c_req_data          ),
        .slv2_rsp_vld               ( i2c_rsp_vld           ),
        .slv2_rsp_rdy               ( i2c_rsp_rdy           ),
        .slv2_rsp_excp              ( i2c_rsp_excp          ),
        .slv2_rsp_data              ( i2c_rsp_data          ),

        .slv3_req_vld               ( spi0_req_vld          ),
        .slv3_req_rdy               ( spi0_req_rdy          ),
        .slv3_req_read              ( spi0_req_read         ),
        .slv3_req_addr              ( spi0_req_addr         ),
        .slv3_req_mask              ( spi0_req_mask         ),
        .slv3_req_data              ( spi0_req_data         ),
        .slv3_rsp_vld               ( spi0_rsp_vld          ),
        .slv3_rsp_rdy               ( spi0_rsp_rdy          ),
        .slv3_rsp_excp              ( spi0_rsp_excp         ),
        .slv3_rsp_data              ( spi0_rsp_data         ),

        .slv4_req_vld               ( spi1_req_vld          ),
        .slv4_req_rdy               ( spi1_req_rdy          ),
        .slv4_req_read              ( spi1_req_read         ),
        .slv4_req_addr              ( spi1_req_addr         ),
        .slv4_req_mask              ( spi1_req_mask         ),
        .slv4_req_data              ( spi1_req_data         ),
        .slv4_rsp_vld               ( spi1_rsp_vld          ),
        .slv4_rsp_rdy               ( spi1_rsp_rdy          ),
        .slv4_rsp_excp              ( spi1_rsp_excp         ),
        .slv4_rsp_data              ( spi1_rsp_data         ),

        .slv5_req_vld               ( tmr_req_vld           ),
        .slv5_req_rdy               ( tmr_req_rdy           ),
        .slv5_req_read              ( tmr_req_read          ),
        .slv5_req_addr              ( tmr_req_addr          ),
        .slv5_req_mask              ( tmr_req_mask          ),
        .slv5_req_data              ( tmr_req_data          ),
        .slv5_rsp_vld               ( tmr_rsp_vld           ),
        .slv5_rsp_rdy               ( tmr_rsp_rdy           ),
        .slv5_rsp_excp              ( tmr_rsp_excp          ),
        .slv5_rsp_data              ( tmr_rsp_data          ),

        .slv6_req_vld               ( wdt_req_vld           ),
        .slv6_req_rdy               ( wdt_req_rdy           ),
        .slv6_req_read              ( wdt_req_read          ),
        .slv6_req_addr              ( wdt_req_addr          ),
        .slv6_req_mask              ( wdt_req_mask          ),
        .slv6_req_data              ( wdt_req_data          ),
        .slv6_rsp_vld               ( wdt_rsp_vld           ),
        .slv6_rsp_rdy               ( wdt_rsp_rdy           ),
        .slv6_rsp_excp              ( wdt_rsp_excp          ),
        .slv6_rsp_data              ( wdt_rsp_data          ),

        .slv7_req_vld               ( dbg_req_vld           ),
        .slv7_req_rdy               ( dbg_req_rdy           ),
        .slv7_req_read              ( dbg_req_read          ),
        .slv7_req_addr              ( dbg_req_addr          ),
        .slv7_req_mask              ( dbg_req_mask          ),
        .slv7_req_data              ( dbg_req_data          ),
        .slv7_rsp_vld               ( dbg_rsp_vld           ),
        .slv7_rsp_rdy               ( dbg_rsp_rdy           ),
        .slv7_rsp_excp              ( dbg_rsp_excp          ),
        .slv7_rsp_data              ( dbg_rsp_data          )
    );

    // GPIO.
    uv_gpio
    #(
        .ALEN                       ( GPIO_BASE_LSB         ),
        .DLEN                       ( DLEN                  ),
        .MLEN                       ( MLEN                  ),
        .IO_NUM                     ( IO_NUM                ),
        .MUX_IO_NUM                 ( MUX_IO_NUM            )
    )
    u_gpio
    (
        .clk                        ( clk                   ),
        .rst_n                      ( rst_n                 ),

        .gpio_req_vld               ( gpio_req_vld          ),
        .gpio_req_rdy               ( gpio_req_rdy          ),
        .gpio_req_read              ( gpio_req_read         ),
        .gpio_req_addr              ( gpio_req_offset       ),
        .gpio_req_mask              ( gpio_req_mask         ),
        .gpio_req_data              ( gpio_req_data         ),

        .gpio_rsp_vld               ( gpio_rsp_vld          ),
        .gpio_rsp_rdy               ( gpio_rsp_rdy          ),
        .gpio_rsp_excp              ( gpio_rsp_excp         ),
        .gpio_rsp_data              ( gpio_rsp_data         ),

        .gpio_mode                  ( gpio_mode             ),

        .gpio_pu                    ( dev_gpio_pu           ),
        .gpio_pd                    ( dev_gpio_pd           ),
        .gpio_ie                    ( dev_gpio_ie           ),
        .gpio_in                    ( dev_gpio_in           ),
        .gpio_oe                    ( dev_gpio_oe           ),
        .gpio_out                   ( dev_gpio_out          ),
        .gpio_irq                   ( gpio_irq              )
    );

    // UART.
    uv_uart
    #(
        .ALEN                       ( UART_BASE_LSB         ),
        .DLEN                       ( DLEN                  ),
        .MLEN                       ( MLEN                  )
    )
    u_uart
    (
        .clk                        ( clk                   ),
        .rst_n                      ( rst_n                 ),

        .uart_req_vld               ( uart_req_vld          ),
        .uart_req_rdy               ( uart_req_rdy          ),
        .uart_req_read              ( uart_req_read         ),
        .uart_req_addr              ( uart_req_offset       ),
        .uart_req_mask              ( uart_req_mask         ),
        .uart_req_data              ( uart_req_data         ),

        .uart_rsp_vld               ( uart_rsp_vld          ),
        .uart_rsp_rdy               ( uart_rsp_rdy          ),
        .uart_rsp_excp              ( uart_rsp_excp         ),
        .uart_rsp_data              ( uart_rsp_data         ),

        .uart_rx                    ( uart_rx               ),
        .uart_tx                    ( uart_tx               ),

        .uart_irq                   ( uart_irq              )
    );

    // I2C.
    uv_i2c
    #(
        .ALEN                       ( I2C_BASE_LSB          ),
        .DLEN                       ( DLEN                  ),
        .MLEN                       ( MLEN                  )
    )
    u_i2c
    (
        .clk                        ( clk                   ),
        .rst_n                      ( rst_n                 ),

        .i2c_req_vld                ( i2c_req_vld           ),
        .i2c_req_rdy                ( i2c_req_rdy           ),
        .i2c_req_read               ( i2c_req_read          ),
        .i2c_req_addr               ( i2c_req_offset        ),
        .i2c_req_mask               ( i2c_req_mask          ),
        .i2c_req_data               ( i2c_req_data          ),

        .i2c_rsp_vld                ( i2c_rsp_vld           ),
        .i2c_rsp_rdy                ( i2c_rsp_rdy           ),
        .i2c_rsp_excp               ( i2c_rsp_excp          ),
        .i2c_rsp_data               ( i2c_rsp_data          ),

        .i2c_scl_in                 ( i2c_scl_in            ),
        .i2c_scl_out                ( i2c_scl_out           ),
        .i2c_scl_oen                ( i2c_scl_oen           ),
        .i2c_sda_in                 ( i2c_sda_in            ),
        .i2c_sda_out                ( i2c_sda_out           ),
        .i2c_sda_oen                ( i2c_sda_oen           ),

        .i2c_irq                    ( i2c_irq               )
    );

    // SPIs.
    uv_spi
    #(
        .ALEN                       ( SPI0_BASE_LSB         ),
        .DLEN                       ( DLEN                  ),
        .MLEN                       ( MLEN                  ),
        .CS_NUM                     ( 1                     )
    )
    u_spi0
    (
        .clk                        ( clk                   ),
        .rst_n                      ( rst_n                 ),

        .spi_req_vld                ( spi0_req_vld          ),
        .spi_req_rdy                ( spi0_req_rdy          ),
        .spi_req_read               ( spi0_req_read         ),
        .spi_req_addr               ( spi0_req_offset       ),
        .spi_req_mask               ( spi0_req_mask         ),
        .spi_req_data               ( spi0_req_data         ),

        .spi_rsp_vld                ( spi0_rsp_vld          ),
        .spi_rsp_rdy                ( spi0_rsp_rdy          ),
        .spi_rsp_excp               ( spi0_rsp_excp         ),
        .spi_rsp_data               ( spi0_rsp_data         ),

        .spi_cs                     ( spi0_cs               ),
        .spi_sck                    ( spi0_sck              ),
        .spi_mosi                   ( spi0_mosi             ),
        .spi_miso                   ( spi0_miso             ),

        .spi_irq                    ( spi0_irq              )
    );

    uv_spi
    #(
        .ALEN                       ( SPI1_BASE_LSB         ),
        .DLEN                       ( DLEN                  ),
        .MLEN                       ( MLEN                  ),
        .CS_NUM                     ( 1                     )
    )
    u_spi1
    (
        .clk                        ( clk                   ),
        .rst_n                      ( rst_n                 ),

        .spi_req_vld                ( spi1_req_vld          ),
        .spi_req_rdy                ( spi1_req_rdy          ),
        .spi_req_read               ( spi1_req_read         ),
        .spi_req_addr               ( spi1_req_offset       ),
        .spi_req_mask               ( spi1_req_mask         ),
        .spi_req_data               ( spi1_req_data         ),

        .spi_rsp_vld                ( spi1_rsp_vld          ),
        .spi_rsp_rdy                ( spi1_rsp_rdy          ),
        .spi_rsp_excp               ( spi1_rsp_excp         ),
        .spi_rsp_data               ( spi1_rsp_data         ),

        .spi_cs                     ( spi1_cs               ),
        .spi_sck                    ( spi1_sck              ),
        .spi_mosi                   ( spi1_mosi             ),
        .spi_miso                   ( spi1_miso             ),

        .spi_irq                    ( spi1_irq              )
    );

    // Multi-channel Timer.
    uv_tmr
    #(
        .ALEN                       ( TMR_BASE_LSB          ),
        .DLEN                       ( DLEN                  ),
        .MLEN                       ( MLEN                  )
    )
    u_tmr
    (
        .clk                        ( clk                   ),
        .rst_n                      ( rst_n                 ),

        // Low-speed clock for timer.
        .low_clk                    ( low_clk               ),

        .tmr_req_vld                ( tmr_req_vld           ),
        .tmr_req_rdy                ( tmr_req_rdy           ),
        .tmr_req_read               ( tmr_req_read          ),
        .tmr_req_addr               ( tmr_req_offset        ),
        .tmr_req_mask               ( tmr_req_mask          ),
        .tmr_req_data               ( tmr_req_data          ),

        .tmr_rsp_vld                ( tmr_rsp_vld           ),
        .tmr_rsp_rdy                ( tmr_rsp_rdy           ),
        .tmr_rsp_excp               ( tmr_rsp_excp          ),
        .tmr_rsp_data               ( tmr_rsp_data          ),

        .tmr_irq                    ( tmr_irq               ),
        .tmr_evt                    ( tmr_evt               )
    );

    // Watch Dog Timer.
    uv_wdt
    #(
        .ALEN                       ( WDT_BASE_LSB          ),
        .DLEN                       ( DLEN                  ),
        .MLEN                       ( MLEN                  )
    )
    u_wdt
    (
        .clk                        ( clk                   ),
        .rst_n                      ( rst_n                 ),

        // Low-speed clock for timer.
        .low_clk                    ( low_clk               ),

        .wdt_req_vld                ( wdt_req_vld           ),
        .wdt_req_rdy                ( wdt_req_rdy           ),
        .wdt_req_read               ( wdt_req_read          ),
        .wdt_req_addr               ( wdt_req_offset        ),
        .wdt_req_mask               ( wdt_req_mask          ),
        .wdt_req_data               ( wdt_req_data          ),

        .wdt_rsp_vld                ( wdt_rsp_vld           ),
        .wdt_rsp_rdy                ( wdt_rsp_rdy           ),
        .wdt_rsp_excp               ( wdt_rsp_excp          ),
        .wdt_rsp_data               ( wdt_rsp_data          ),

        .wdt_irq                    ( wdt_irq               ),
        .wdt_rst_n                  ( wdt_rst_n             )
    );

    // Debugger.
    uv_dbg
    #(
        .ALEN                       ( DBG_BASE_LSB          ),
        .DLEN                       ( DLEN                  ),
        .MLEN                       ( MLEN                  )
    )
    u_dbg
    (
        .clk                        ( clk                   ),
        .rst_n                      ( rst_n                 ),

        .dbg_req_vld                ( dbg_req_vld           ),
        .dbg_req_rdy                ( dbg_req_rdy           ),
        .dbg_req_read               ( dbg_req_read          ),
        .dbg_req_addr               ( dbg_req_offset        ),
        .dbg_req_mask               ( dbg_req_mask          ),
        .dbg_req_data               ( dbg_req_data          ),

        .dbg_rsp_vld                ( dbg_rsp_vld           ),
        .dbg_rsp_rdy                ( dbg_rsp_rdy           ),
        .dbg_rsp_excp               ( dbg_rsp_excp          ),
        .dbg_rsp_data               ( dbg_rsp_data          )
    );

    // IO Mux.
    uv_iomux
    #(
        .IO_NUM                     ( IO_NUM                )
    )
    u_iomux
    (
        .clk                        ( clk                   ),
        .rst_n                      ( rst_n                 ),

        .gpio_mode                  ( gpio_mode             ),

        .uart_rx                    ( uart_rx               ),
        .uart_tx                    ( uart_tx               ),

        .spi0_cs                    ( spi0_cs               ),
        .spi0_sck                   ( spi0_sck              ),
        .spi0_mosi                  ( spi0_mosi             ),
        .spi0_miso                  ( spi0_miso             ),

        .spi1_cs                    ( spi1_cs               ),
        .spi1_sck                   ( spi1_sck              ),
        .spi1_mosi                  ( spi1_mosi             ),
        .spi1_miso                  ( spi1_miso             ),

        .src_gpio_pu                ( dev_gpio_pu           ),
        .src_gpio_pd                ( dev_gpio_pd           ),
        .src_gpio_ie                ( dev_gpio_ie           ),
        .src_gpio_in                ( dev_gpio_in           ),
        .src_gpio_oe                ( dev_gpio_oe           ),
        .src_gpio_out               ( dev_gpio_out          ),

        .dst_gpio_pu                ( gpio_pu               ),
        .dst_gpio_pd                ( gpio_pd               ),
        .dst_gpio_ie                ( gpio_ie               ),
        .dst_gpio_in                ( gpio_in               ),
        .dst_gpio_oe                ( gpio_oe               ),
        .dst_gpio_out               ( gpio_out              )
    );

endmodule

//************************************************************
// See LICENSE for license details.
//
// Module: uv_dev_subsys
//
// Designer: Owen
//
// Description:
//      Device subsystem with sysbus, shared memory,
//      peripherals & system-level controller.
//************************************************************

`timescale 1ns / 1ps

module uv_dev_subsys
#(
    parameter ALEN                  = 32,
    parameter DLEN                  = 32,
    parameter MLEN                  = DLEN / 8,
    parameter IO_NUM                = 32
)
(
    input                           sys_clk,
    input                           aon_clk,
    input                           low_clk,
    input                           sys_rst_n,
    input                           por_rst_n,

    // Inst device access.
    input                           dev_i_req_vld,
    output                          dev_i_req_rdy,
    input  [ALEN-1:0]               dev_i_req_addr,
    output                          dev_i_rsp_vld,
    input                           dev_i_rsp_rdy,
    output [1:0]                    dev_i_rsp_excp,
    output [DLEN-1:0]               dev_i_rsp_data,

    // Data device access.
    input                           dev_d_req_vld,
    output                          dev_d_req_rdy,
    input                           dev_d_req_read,
    input  [ALEN-1:0]               dev_d_req_addr,
    input  [MLEN-1:0]               dev_d_req_mask,
    input  [DLEN-1:0]               dev_d_req_data,
    output                          dev_d_rsp_vld,
    input                           dev_d_rsp_rdy,
    output [1:0]                    dev_d_rsp_excp,
    output [DLEN-1:0]               dev_d_rsp_data,

    // DMA device access.
    input                           dma_req_vld,
    output                          dma_req_rdy,
    input                           dma_req_read,
    input  [ALEN-1:0]               dma_req_addr,
    input  [MLEN-1:0]               dma_req_mask,
    input  [DLEN-1:0]               dma_req_data,
    output                          dma_rsp_vld,
    input                           dma_rsp_rdy,
    output [1:0]                    dma_rsp_excp,
    output [DLEN-1:0]               dma_rsp_data,

    // Debug device access.
    input                           dbg_req_vld,
    output                          dbg_req_rdy,
    input                           dbg_req_read,
    input  [ALEN-1:0]               dbg_req_addr,
    input  [MLEN-1:0]               dbg_req_mask,
    input  [DLEN-1:0]               dbg_req_data,
    output                          dbg_rsp_vld,
    input                           dbg_rsp_rdy,
    output [1:0]                    dbg_rsp_excp,
    output [DLEN-1:0]               dbg_rsp_data,

    // Control & status with core.
    input                           tmr_irq_clr,
    output [ALEN-1:0]               rst_vec,
    output                          ext_irq,
    output                          sft_irq,
    output                          tmr_irq,
    output [63:0]                   tmr_val,

    // Control & status with SOC.
    output                          slc_rst_n,
    output                          wdt_rst_n,

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
    
    output [IO_NUM-1:0]             gpio_pu,
    output [IO_NUM-1:0]             gpio_pd,
    output [IO_NUM-1:0]             gpio_ie,
    input  [IO_NUM-1:0]             gpio_in,
    output [IO_NUM-1:0]             gpio_oe,
    output [IO_NUM-1:0]             gpio_out
);

    localparam UDLY                 = 1;
    localparam RESV_BASE_LSB        = 26;
    localparam RESV_BASE_ADDR       = 6'h0;
    localparam ROM_BASE_LSB         = 26;
    localparam ROM_BASE_ADDR        = 6'h1;
    localparam SLC_BASE_LSB         = 26;
    localparam SLC_BASE_ADDR        = 6'h2;
    localparam SRAM_BASE_LSB        = 28;
    localparam SRAM_BASE_ADDR       = 4'h1;
    localparam EFLASH_BASE_LSB      = 28;
    localparam EFLASH_BASE_ADDR     = 4'h2;
    localparam PERIP_BASE_LSB       = 16;
    localparam PERIP_BASE_ADDR      = 16'h7000;
    localparam DMA_BASE_LSB         = 16;
    localparam DMA_BASE_ADDR        = 16'h7001;
    localparam ROM_START_ADDR       = {{(ALEN-ROM_BASE_LSB-1){1'b0}}, ROM_BASE_ADDR, {ROM_BASE_LSB{1'b0}}};

    localparam ROM_AW               = 10;
    localparam SRAM_AW              = 14;
    localparam SRAM_DP              = 2**SRAM_AW;
    localparam EFLASH_AW            = 18;
    localparam EFLASH_DP            = 2**SRAM_AW;
    localparam EXT_IRQ_NUM          = 64;
    localparam IRQ_PRI_NUM          = 8;

    localparam ROM_ICG_INDEX        = 0;
    localparam SRAM_ICG_INDEX       = 1;
    localparam EFLASH_ICG_INDEX     = 2;
    localparam DMA_ICG_INDEX        = 3;
    localparam PERIP_ICG_NUM        = 8;

    genvar i;

    wire                            bus_clk;
    wire                            bus_rst_n;
    wire [3:0]                      bus_mst_dev_vld;
    wire [7:0]                      bus_slv_dev_vld;

    wire                            rom_clk;
    wire                            rom_rst_n;
    wire                            rom_req_vld;
    wire                            rom_req_rdy;
    wire                            rom_req_read;
    wire [ALEN-1:0]                 rom_req_addr;
    wire [MLEN-1:0]                 rom_req_mask;
    wire [DLEN-1:0]                 rom_req_data;
    wire                            rom_rsp_vld;
    wire                            rom_rsp_rdy;
    wire [1:0]                      rom_rsp_excp;
    wire [DLEN-1:0]                 rom_rsp_data;
    wire [ROM_BASE_LSB-1:0]         rom_req_offset;

    wire                            tmr_clk;
    wire                            slc_req_vld;
    wire                            slc_req_rdy;
    wire                            slc_req_read;
    wire [ALEN-1:0]                 slc_req_addr;
    wire [MLEN-1:0]                 slc_req_mask;
    wire [DLEN-1:0]                 slc_req_data;
    wire                            slc_rsp_vld;
    wire                            slc_rsp_rdy;
    wire [1:0]                      slc_rsp_excp;
    wire [DLEN-1:0]                 slc_rsp_data;
    wire [SLC_BASE_LSB-1:0]         slc_req_offset;

    wire                            sram_clk;
    wire                            sram_rst_n;
    wire                            sram_req_vld;
    wire                            sram_req_rdy;
    wire                            sram_req_read;
    wire [ALEN-1:0]                 sram_req_addr;
    wire [MLEN-1:0]                 sram_req_mask;
    wire [DLEN-1:0]                 sram_req_data;
    wire                            sram_rsp_vld;
    wire                            sram_rsp_rdy;
    wire [1:0]                      sram_rsp_excp;
    wire [DLEN-1:0]                 sram_rsp_data;
    wire [SRAM_BASE_LSB-1:0]        sram_req_offset;

    wire                            eflash_clk;
    wire                            eflash_rst_n;
    wire                            eflash_req_vld;
    wire                            eflash_req_rdy;
    wire                            eflash_req_read;
    wire [ALEN-1:0]                 eflash_req_addr;
    wire [MLEN-1:0]                 eflash_req_mask;
    wire [DLEN-1:0]                 eflash_req_data;
    wire                            eflash_rsp_vld;
    wire                            eflash_rsp_rdy;
    wire [1:0]                      eflash_rsp_excp;
    wire [DLEN-1:0]                 eflash_rsp_data;
    wire [EFLASH_BASE_LSB-1:0]      eflash_req_offset;

    wire                            perip_clk;
    wire                            perip_rst_n;
    wire                            perip_req_vld;
    wire                            perip_req_rdy;
    wire                            perip_req_read;
    wire [ALEN-1:0]                 perip_req_addr;
    wire [MLEN-1:0]                 perip_req_mask;
    wire [DLEN-1:0]                 perip_req_data;
    wire                            perip_rsp_vld;
    wire                            perip_rsp_rdy;
    wire [1:0]                      perip_rsp_excp;
    wire [DLEN-1:0]                 perip_rsp_data;
    wire [PERIP_BASE_LSB-1:0]       perip_req_offset;

    wire                            dma_clk;
    wire                            dma_rst_n;
    wire                            dma_slv_req_vld;
    wire                            dma_slv_req_rdy;
    wire                            dma_slv_req_read;
    wire [ALEN-1:0]                 dma_slv_req_addr;
    wire [MLEN-1:0]                 dma_slv_req_mask;
    wire [DLEN-1:0]                 dma_slv_req_data;
    wire                            dma_slv_rsp_vld;
    wire                            dma_slv_rsp_rdy;
    wire [1:0]                      dma_slv_rsp_excp;
    wire [DLEN-1:0]                 dma_slv_rsp_data;
    wire [DMA_BASE_LSB-1:0]         dma_slv_req_offset;

    wire [EXT_IRQ_NUM-1:0]          ext_irq_src;
    wire [31:0]                     dev_rst_n;
    wire                            gpio_mode;
    wire [IO_NUM+7:0]               perip_irq;

    // Bus Matrix.
    assign bus_clk                  = sys_clk;
    assign bus_rst_n                = sys_rst_n & por_rst_n;
    assign bus_mst_dev_vld          = 4'hF;
    assign bus_slv_dev_vld          = 8'h3F;

    uv_bus_fab_4x8
    #(
        .ALEN                       ( ALEN                  ),
        .DLEN                       ( DLEN                  ),
        .MLEN                       ( MLEN                  ),
        .SLV0_BASE_LSB              ( ROM_BASE_LSB          ),
        .SLV0_BASE_ADDR             ( ROM_BASE_ADDR         ),
        .SLV1_BASE_LSB              ( SLC_BASE_LSB          ),
        .SLV1_BASE_ADDR             ( SLC_BASE_ADDR         ),
        .SLV2_BASE_LSB              ( SRAM_BASE_LSB         ),
        .SLV2_BASE_ADDR             ( SRAM_BASE_ADDR        ),
        .SLV3_BASE_LSB              ( EFLASH_BASE_LSB       ),
        .SLV3_BASE_ADDR             ( EFLASH_BASE_ADDR      ),
        .SLV4_BASE_LSB              ( PERIP_BASE_LSB        ),
        .SLV4_BASE_ADDR             ( PERIP_BASE_ADDR       ),
        .SLV5_BASE_LSB              ( DMA_BASE_LSB          ),
        .SLV5_BASE_ADDR             ( DMA_BASE_ADDR         )
    )
    u_devbus
    (
        .clk                        ( bus_clk               ),
        .rst_n                      ( bus_rst_n             ),

        // Device enabling.
        .mst_dev_vld                ( bus_mst_dev_vld       ),
        .slv_dev_vld                ( bus_slv_dev_vld       ),

        // Masters.
        .mst0_req_vld               ( dev_i_req_vld         ),
        .mst0_req_rdy               ( dev_i_req_rdy         ),
        .mst0_req_read              ( 1'b1                  ),
        .mst0_req_addr              ( dev_i_req_addr        ),
        .mst0_req_mask              ( {MLEN{1'b1}}          ),
        .mst0_req_data              ( {DLEN{1'b0}}          ),
        .mst0_rsp_vld               ( dev_i_rsp_vld         ),
        .mst0_rsp_rdy               ( dev_i_rsp_rdy         ),
        .mst0_rsp_excp              ( dev_i_rsp_excp        ),
        .mst0_rsp_data              ( dev_i_rsp_data        ),

        .mst1_req_vld               ( dev_d_req_vld         ),
        .mst1_req_rdy               ( dev_d_req_rdy         ),
        .mst1_req_read              ( dev_d_req_read        ),
        .mst1_req_addr              ( dev_d_req_addr        ),
        .mst1_req_mask              ( dev_d_req_mask        ),
        .mst1_req_data              ( dev_d_req_data        ),
        .mst1_rsp_vld               ( dev_d_rsp_vld         ),
        .mst1_rsp_rdy               ( dev_d_rsp_rdy         ),
        .mst1_rsp_excp              ( dev_d_rsp_excp        ),
        .mst1_rsp_data              ( dev_d_rsp_data        ),

        .mst2_req_vld               ( dma_req_vld           ),
        .mst2_req_rdy               ( dma_req_rdy           ),
        .mst2_req_read              ( dma_req_read          ),
        .mst2_req_addr              ( dma_req_addr          ),
        .mst2_req_mask              ( dma_req_mask          ),
        .mst2_req_data              ( dma_req_data          ),
        .mst2_rsp_vld               ( dma_rsp_vld           ),
        .mst2_rsp_rdy               ( dma_rsp_rdy           ),
        .mst2_rsp_excp              ( dma_rsp_excp          ),
        .mst2_rsp_data              ( dma_rsp_data          ),

        .mst3_req_vld               ( dbg_req_vld           ),
        .mst3_req_rdy               ( dbg_req_rdy           ),
        .mst3_req_read              ( dbg_req_read          ),
        .mst3_req_addr              ( dbg_req_addr          ),
        .mst3_req_mask              ( dbg_req_mask          ),
        .mst3_req_data              ( dbg_req_data          ),
        .mst3_rsp_vld               ( dbg_rsp_vld           ),
        .mst3_rsp_rdy               ( dbg_rsp_rdy           ),
        .mst3_rsp_excp              ( dbg_rsp_excp          ),
        .mst3_rsp_data              ( dbg_rsp_data          ),

        // Slaves.
        .slv0_req_vld               ( rom_req_vld           ),
        .slv0_req_rdy               ( rom_req_rdy           ),
        .slv0_req_read              ( rom_req_read          ),
        .slv0_req_addr              ( rom_req_addr          ),
        .slv0_req_mask              ( rom_req_mask          ),
        .slv0_req_data              ( rom_req_data          ),
        .slv0_rsp_vld               ( rom_rsp_vld           ),
        .slv0_rsp_rdy               ( rom_rsp_rdy           ),
        .slv0_rsp_excp              ( rom_rsp_excp          ),
        .slv0_rsp_data              ( rom_rsp_data          ),

        .slv1_req_vld               ( slc_req_vld           ),
        .slv1_req_rdy               ( slc_req_rdy           ),
        .slv1_req_read              ( slc_req_read          ),
        .slv1_req_addr              ( slc_req_addr          ),
        .slv1_req_mask              ( slc_req_mask          ),
        .slv1_req_data              ( slc_req_data          ),
        .slv1_rsp_vld               ( slc_rsp_vld           ),
        .slv1_rsp_rdy               ( slc_rsp_rdy           ),
        .slv1_rsp_excp              ( slc_rsp_excp          ),
        .slv1_rsp_data              ( slc_rsp_data          ),

        .slv2_req_vld               ( sram_req_vld          ),
        .slv2_req_rdy               ( sram_req_rdy          ),
        .slv2_req_read              ( sram_req_read         ),
        .slv2_req_addr              ( sram_req_addr         ),
        .slv2_req_mask              ( sram_req_mask         ),
        .slv2_req_data              ( sram_req_data         ),
        .slv2_rsp_vld               ( sram_rsp_vld          ),
        .slv2_rsp_rdy               ( sram_rsp_rdy          ),
        .slv2_rsp_excp              ( sram_rsp_excp         ),
        .slv2_rsp_data              ( sram_rsp_data         ),

        .slv3_req_vld               ( eflash_req_vld        ),
        .slv3_req_rdy               ( eflash_req_rdy        ),
        .slv3_req_read              ( eflash_req_read       ),
        .slv3_req_addr              ( eflash_req_addr       ),
        .slv3_req_mask              ( eflash_req_mask       ),
        .slv3_req_data              ( eflash_req_data       ),
        .slv3_rsp_vld               ( eflash_rsp_vld        ),
        .slv3_rsp_rdy               ( eflash_rsp_rdy        ),
        .slv3_rsp_excp              ( eflash_rsp_excp       ),
        .slv3_rsp_data              ( eflash_rsp_data       ),

        .slv4_req_vld               ( perip_req_vld         ),
        .slv4_req_rdy               ( perip_req_rdy         ),
        .slv4_req_read              ( perip_req_read        ),
        .slv4_req_addr              ( perip_req_addr        ),
        .slv4_req_mask              ( perip_req_mask        ),
        .slv4_req_data              ( perip_req_data        ),
        .slv4_rsp_vld               ( perip_rsp_vld         ),
        .slv4_rsp_rdy               ( perip_rsp_rdy         ),
        .slv4_rsp_excp              ( perip_rsp_excp        ),
        .slv4_rsp_data              ( perip_rsp_data        ),

        .slv5_req_vld               ( dma_slv_req_vld       ),
        .slv5_req_rdy               ( dma_slv_req_rdy       ),
        .slv5_req_read              ( dma_slv_req_read      ),
        .slv5_req_addr              ( dma_slv_req_addr      ),
        .slv5_req_mask              ( dma_slv_req_mask      ),
        .slv5_req_data              ( dma_slv_req_data      ),
        .slv5_rsp_vld               ( dma_slv_rsp_vld       ),
        .slv5_rsp_rdy               ( dma_slv_rsp_rdy       ),
        .slv5_rsp_excp              ( dma_slv_rsp_excp      ),
        .slv5_rsp_data              ( dma_slv_rsp_data      ),

        .slv6_req_vld               (                       ),
        .slv6_req_rdy               ( 1'b1                  ),
        .slv6_req_read              (                       ),
        .slv6_req_addr              (                       ),
        .slv6_req_mask              (                       ),
        .slv6_req_data              (                       ),
        .slv6_rsp_vld               ( 1'b0                  ),
        .slv6_rsp_rdy               (                       ),
        .slv6_rsp_excp              ( 2'b0                  ),
        .slv6_rsp_data              ( {DLEN{1'b0}}          ),

        .slv7_req_vld               (                       ),
        .slv7_req_rdy               ( 1'b1                  ),
        .slv7_req_read              (                       ),
        .slv7_req_addr              (                       ),
        .slv7_req_mask              (                       ),
        .slv7_req_data              (                       ),
        .slv7_rsp_vld               ( 1'b0                  ),
        .slv7_rsp_rdy               (                       ),
        .slv7_rsp_excp              ( 2'b0                  ),
        .slv7_rsp_data              ( {DLEN{1'b0}}          )
    );

    // ROM.
    assign rom_clk                  = sys_clk;
    assign rom_rst_n                = sys_rst_n & por_rst_n;
    assign rom_req_offset           = rom_req_addr[ROM_BASE_LSB-1:0];

    uv_rom
    #(
        .ALEN                       ( ROM_BASE_LSB          ),
        .DLEN                       ( DLEN                  ),
        .MLEN                       ( MLEN                  ),
        .ROM_AW                     ( ROM_AW                )
    )
    u_rom
    (
        .clk                        ( rom_clk               ),
        .rst_n                      ( rom_rst_n             ),

        .rom_req_vld                ( rom_req_vld           ),
        .rom_req_rdy                ( rom_req_rdy           ),
        .rom_req_read               ( rom_req_read          ),
        .rom_req_addr               ( rom_req_offset        ),
        .rom_req_mask               ( rom_req_mask          ),
        .rom_req_data               ( rom_req_data          ),

        .rom_rsp_vld                ( rom_rsp_vld           ),
        .rom_rsp_rdy                ( rom_rsp_rdy           ),
        .rom_rsp_excp               ( rom_rsp_excp          ),
        .rom_rsp_data               ( rom_rsp_data          )
    );

    // SLC.
    assign slc_req_offset           = slc_req_addr[SLC_BASE_LSB-1:0];
    assign ext_irq_src              = {{(EXT_IRQ_NUM-IO_NUM-8){1'b0}}, perip_irq};

    uv_slc
    #(
        .ALEN                       ( SLC_BASE_LSB          ),
        .DLEN                       ( DLEN                  ),
        .MLEN                       ( MLEN                  ),
        .RST_VEC_LEN                ( ALEN                  ),
        .RST_VEC_DEF                ( ROM_START_ADDR        ),
        .EXT_IRQ_NUM                ( EXT_IRQ_NUM           ),
        .IRQ_PRI_NUM                ( IRQ_PRI_NUM           )
    )
    u_slc
    (
        .sys_clk                    ( sys_clk               ),
        .aon_clk                    ( aon_clk               ),
        .sys_rst_n                  ( sys_rst_n             ),
        .por_rst_n                  ( por_rst_n             ),

        .slc_req_vld                ( slc_req_vld           ),
        .slc_req_rdy                ( slc_req_rdy           ),
        .slc_req_read               ( slc_req_read          ),
        .slc_req_addr               ( slc_req_offset        ),
        .slc_req_mask               ( slc_req_mask          ),
        .slc_req_data               ( slc_req_data          ),

        .slc_rsp_vld                ( slc_rsp_vld           ),
        .slc_rsp_rdy                ( slc_rsp_rdy           ),
        .slc_rsp_excp               ( slc_rsp_excp          ),
        .slc_rsp_data               ( slc_rsp_data          ),

        .tmr_irq_clr                ( tmr_irq_clr           ),
        .ext_irq_src                ( ext_irq_src           ),

        .slc_rst_n                  ( slc_rst_n             ),
        .dev_rst_n                  ( dev_rst_n             ),
        .gpio_mode                  ( gpio_mode             ),
        .sys_icg                    (                       ),
        .rst_vec                    ( rst_vec               ),
        .ext_irq                    ( ext_irq               ),
        .sft_irq                    ( sft_irq               ),
        .tmr_irq                    ( tmr_irq               ),
        .tmr_val                    ( tmr_val               )
    );

    // SRAM.
    assign sram_clk                 = sys_clk;
    assign sram_rst_n               = sys_rst_n & por_rst_n;
    assign sram_req_offset          = sram_req_addr[SRAM_BASE_LSB-1:0];

    uv_dev_sram
    #(
        .ALEN                       ( SRAM_BASE_LSB         ),
        .DLEN                       ( DLEN                  ),
        .MLEN                       ( MLEN                  ),
        .SRAM_AW                    ( SRAM_AW               ),
        .SRAM_DP                    ( SRAM_DP               )
    )
    u_sram
    (
        .clk                        ( sram_clk              ),
        .rst_n                      ( sram_rst_n            ),

        .sram_req_vld               ( sram_req_vld          ),
        .sram_req_rdy               ( sram_req_rdy          ),
        .sram_req_read              ( sram_req_read         ),
        .sram_req_addr              ( sram_req_offset       ),
        .sram_req_mask              ( sram_req_mask         ),
        .sram_req_data              ( sram_req_data         ),

        .sram_rsp_vld               ( sram_rsp_vld          ),
        .sram_rsp_rdy               ( sram_rsp_rdy          ),
        .sram_rsp_excp              ( sram_rsp_excp         ),
        .sram_rsp_data              ( sram_rsp_data         )
    );

    // EFLASH.
    assign eflash_clk               = sys_clk;
    assign eflash_rst_n             = sys_rst_n & por_rst_n;
    assign eflash_req_offset        = eflash_req_addr[EFLASH_BASE_LSB-1:0];

    uv_eflash
    #(
        .ALEN                       ( EFLASH_BASE_LSB       ),
        .DLEN                       ( DLEN                  ),
        .MLEN                       ( MLEN                  ),
        .EFLASH_AW                  ( EFLASH_AW             ),
        .EFLASH_DP                  ( EFLASH_DP             )
    )
    u_eflash
    (
        .clk                        ( eflash_clk            ),
        .rst_n                      ( eflash_rst_n          ),

        .eflash_req_vld             ( eflash_req_vld        ),
        .eflash_req_rdy             ( eflash_req_rdy        ),
        .eflash_req_read            ( eflash_req_read       ),
        .eflash_req_addr            ( eflash_req_offset     ),
        .eflash_req_mask            ( eflash_req_mask       ),
        .eflash_req_data            ( eflash_req_data       ),

        .eflash_rsp_vld             ( eflash_rsp_vld        ),
        .eflash_rsp_rdy             ( eflash_rsp_rdy        ),
        .eflash_rsp_excp            ( eflash_rsp_excp       ),
        .eflash_rsp_data            ( eflash_rsp_data       )
    );

    // Peripherals.
    assign peirp_clk                = sys_clk;
    assign peirp_rst_n              = sys_rst_n & por_rst_n;
    assign perip_req_offset         = perip_req_addr[PERIP_BASE_LSB-1:0];

    uv_perip_subsys
    #(
        .ALEN                       ( PERIP_BASE_LSB        ),
        .DLEN                       ( DLEN                  ),
        .MLEN                       ( MLEN                  ),
        .IO_NUM                     ( IO_NUM                )
    )
    u_perip_subsys
    (
        .clk                        ( peirp_clk             ),
        .rst_n                      ( peirp_rst_n           ),
        .low_clk                    ( low_clk               ),

        .perip_req_vld              ( perip_req_vld         ),
        .perip_req_rdy              ( perip_req_rdy         ),
        .perip_req_read             ( perip_req_read        ),
        .perip_req_addr             ( perip_req_offset      ),
        .perip_req_mask             ( perip_req_mask        ),
        .perip_req_data             ( perip_req_data        ),

        .perip_rsp_vld              ( perip_rsp_vld         ),
        .perip_rsp_rdy              ( perip_rsp_rdy         ),
        .perip_rsp_excp             ( perip_rsp_excp        ),
        .perip_rsp_data             ( perip_rsp_data        ),

        .jtag_tck                   ( jtag_tck              ),
        .jtag_tms                   ( jtag_tms              ),
        .jtag_tdi                   ( jtag_tdi              ),
        .jtag_tdo                   ( jtag_tdo              ),

        .i2c_scl_in                 ( i2c_scl_in            ),
        .i2c_scl_out                ( i2c_scl_out           ),
        .i2c_scl_oen                ( i2c_scl_oen           ),
        .i2c_sda_in                 ( i2c_sda_in            ),
        .i2c_sda_out                ( i2c_sda_out           ),
        .i2c_sda_oen                ( i2c_sda_oen           ),
        
        .gpio_mode                  ( gpio_mode             ),
        .perip_irq                  ( perip_irq             ),
        .wdt_rst_n                  ( wdt_rst_n             ),

        .gpio_pu                    ( gpio_pu               ),
        .gpio_pd                    ( gpio_pd               ),
        .gpio_ie                    ( gpio_ie               ),
        .gpio_in                    ( gpio_in               ),
        .gpio_oe                    ( gpio_oe               ),
        .gpio_out                   ( gpio_out              )
    );

endmodule
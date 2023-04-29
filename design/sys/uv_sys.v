//************************************************************
// See LICENSE for license details.
//
// Module: uv_sys
//
// Designer: Owen
//
// Description:
//      System with core & bus.
//************************************************************

`timescale 1ns / 1ps

module uv_sys
#(
    parameter IO_NUM                = 32
)
(
    input                           sys_clk,
    input                           low_clk,
    input                           sys_rst_n,
    input                           por_rst_n,

`ifdef USE_EXT_MEM
    // TODO.
`endif

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

    //-------------------------------------------------------
    // Parameters.
    localparam UDLY                 = 1;
    localparam ARCH_ID              = 64'h235;
    localparam IMPL_ID              = 1;
    localparam HART_ID              = 0;
    localparam VENDOR_ID            = 0;
    localparam ALEN                 = 32;
    localparam ILEN                 = 32;
    localparam XLEN                 = 32;
    localparam MLEN                 = XLEN / 8;
    localparam MEM_BASE_LSB         = 31;
    localparam MEM_BASE_ADDR        = 1'h1;
    localparam DEV_BASE_LSB         = 31;
    localparam DEV_BASE_ADDR        = 1'h0;
    localparam USE_INST_DAM         = 1'b1;
    localparam USE_DATA_DAM         = 1'b1;
    localparam INST_MEM_DW          = USE_INST_DAM ? ILEN : 128;
    localparam INST_MEM_MW          = INST_MEM_DW / 8;
    localparam DATA_MEM_DW          = USE_DATA_DAM ? XLEN : 128;
    localparam DATA_MEM_MW          = DATA_MEM_DW / 8;

    localparam DAM_SRAM_DW          = XLEN;             // XLEN must be larger than ILEN!
    localparam DAM_SRAM_MW          = DAM_SRAM_DW / 8;
    localparam DAM_SRAM_AW          = 15;
    localparam DAM_SRAM_DP          = 2**DAM_SRAM_AW;   // 32768 * 4B = 128KB
    localparam DAM_PORT_DW          = DAM_SRAM_DW;
    localparam DAM_PORT_MW          = DAM_SRAM_MW;
    localparam DAM_PORT_AW          = DAM_SRAM_AW + $clog2(DAM_SRAM_DW / 8);

    //-------------------------------------------------------
    // Signals.
    wire                            gated_clk;
    wire                            async_rst_n;
    wire                            sync_rst_n;

    wire                            core_clk;
    wire                            dev_clk;
    wire                            aon_clk;

    wire                            core_rst_n;
    wire                            dev_rst_n;

    // Reset vector.
    wire [ALEN-1:0]                 rst_vec;

    // Inst memory access.
    wire                            mem_i_req_vld;
    wire                            mem_i_req_rdy;
    wire [ALEN-1:0]                 mem_i_req_addr;

    wire                            mem_i_rsp_vld;
    wire                            mem_i_rsp_rdy;
    wire [1:0]                      mem_i_rsp_excp;
    wire [INST_MEM_DW-1:0]          mem_i_rsp_data;
    
    // Data memory access.
    wire                            mem_d_req_vld;
    wire                            mem_d_req_rdy;
    wire                            mem_d_req_read;
    wire [ALEN-1:0]                 mem_d_req_addr;
    wire [DATA_MEM_MW-1:0]          mem_d_req_mask;
    wire [DATA_MEM_DW-1:0]          mem_d_req_data;

    wire                            mem_d_rsp_vld;
    wire                            mem_d_rsp_rdy;
    wire [1:0]                      mem_d_rsp_excp;
    wire [DATA_MEM_DW-1:0]          mem_d_rsp_data;

    // Inst device access.
    wire                            dev_i_req_vld;
    wire                            dev_i_req_rdy;
    wire [ALEN-1:0]                 dev_i_req_addr;

    wire                            dev_i_rsp_vld;
    wire                            dev_i_rsp_rdy;
    wire [1:0]                      dev_i_rsp_excp;
    wire [XLEN-1:0]                 dev_i_rsp_data;

    // Data device access.
    wire                            dev_d_req_vld;
    wire                            dev_d_req_rdy;
    wire                            dev_d_req_read;
    wire [ALEN-1:0]                 dev_d_req_addr;
    wire [MLEN-1:0]                 dev_d_req_mask;
    wire [XLEN-1:0]                 dev_d_req_data;

    wire                            dev_d_rsp_vld;
    wire                            dev_d_rsp_rdy;
    wire [1:0]                      dev_d_rsp_excp;
    wire [XLEN-1:0]                 dev_d_rsp_data;

    wire                            tmr_irq_clr;
    wire                            core_lp_mode;

    wire                            slc_rst_n;
    wire                            wdt_rst_n;

    wire                            nmi = 1'b0;
    wire                            ext_irq;
    wire                            sft_irq;
    wire                            tmr_irq;
    wire [63:0]                     tmr_val;

    // DAM ports.
    wire                            dam_i_req_vld;
    wire                            dam_i_req_rdy;
    wire                            dam_i_req_read;
    wire [DAM_PORT_AW-1:0]          dam_i_req_addr;
    wire [DAM_PORT_MW-1:0]          dam_i_req_mask;
    wire [DAM_PORT_DW-1:0]          dam_i_req_data;

    wire                            dam_i_rsp_vld;
    wire                            dam_i_rsp_rdy;
    wire [1:0]                      dam_i_rsp_excp;
    wire [DAM_PORT_DW-1:0]          dam_i_rsp_data;

    wire                            dam_d_req_vld;
    wire                            dam_d_req_rdy;
    wire                            dam_d_req_read;
    wire [DAM_PORT_AW-1:0]          dam_d_req_addr;
    wire [DAM_PORT_MW-1:0]          dam_d_req_mask;
    wire [DAM_PORT_DW-1:0]          dam_d_req_data;

    wire                            dam_d_rsp_vld;
    wire                            dam_d_rsp_rdy;
    wire [1:0]                      dam_d_rsp_excp;
    wire [DAM_PORT_DW-1:0]          dam_d_rsp_data;

    //-------------------------------------------------------
    // Clock & reset.
    uv_clk_gate u_sys_clk_gate
    (
        .clk_in                     ( sys_clk               ),
        .clk_en                     ( ~core_lp_mode         ),
        .clk_out                    ( gate_clk              )
    );

    assign core_clk     = gate_clk;
    assign dev_clk      = gate_clk;
    assign aon_clk      = sys_clk;

    uv_rst_sync
    #(
        .SYNC_STAGE                 ( 2                     )
    )
    u_sys_rst_sync
    (
        .clk                        ( sys_clk               ),
        .rst_n                      ( async_rst_n           ),
        .sync_rst_n                 ( sync_rst_n            )
    );

    assign async_rst_n  = sys_rst_n & por_rst_n & slc_rst_n & wdt_rst_n;
    assign core_rst_n   = sync_rst_n;
    assign dev_rst_n    = sync_rst_n;

    //-------------------------------------------------------
    // Core.
    uv_core
    #(  
        .ARCH_ID                    ( ARCH_ID               ),
        .IMPL_ID                    ( IMPL_ID               ),
        .HART_ID                    ( HART_ID               ),
        .VENDOR_ID                  ( VENDOR_ID             ),
        .ALEN                       ( ALEN                  ),
        .ILEN                       ( ILEN                  ),
        .XLEN                       ( XLEN                  ),
        .MLEN                       ( MLEN                  ),
        .MEM_BASE_LSB               ( MEM_BASE_LSB          ),
        .MEM_BASE_ADDR              ( MEM_BASE_ADDR         ),
        .DEV_BASE_LSB               ( DEV_BASE_LSB          ),
        .DEV_BASE_ADDR              ( DEV_BASE_ADDR         ),
        .USE_INST_DAM               ( USE_INST_DAM          ),
        .USE_DATA_DAM               ( USE_DATA_DAM          ),
        .INST_MEM_DW                ( INST_MEM_DW           ),
        .INST_MEM_MW                ( INST_MEM_MW           ),
        .DATA_MEM_DW                ( DATA_MEM_DW           ),
        .DATA_MEM_MW                ( DATA_MEM_MW           )
    )
    u_core
    (
        .clk                        ( core_clk              ),
        .rst_n                      ( core_rst_n            ),

        // Reset vector from system.
        .rst_vec                    ( rst_vec               ),
        
        // Inst memory access.
        .mem_i_req_vld              ( mem_i_req_vld         ),
        .mem_i_req_rdy              ( mem_i_req_rdy         ),
        .mem_i_req_addr             ( mem_i_req_addr        ),

        .mem_i_rsp_vld              ( mem_i_rsp_vld         ),
        .mem_i_rsp_rdy              ( mem_i_rsp_rdy         ),
        .mem_i_rsp_excp             ( mem_i_rsp_excp        ),
        .mem_i_rsp_data             ( mem_i_rsp_data        ),
        
        // Data memory access.
        .mem_d_req_vld              ( mem_d_req_vld         ),
        .mem_d_req_rdy              ( mem_d_req_rdy         ),
        .mem_d_req_read             ( mem_d_req_read        ),
        .mem_d_req_addr             ( mem_d_req_addr        ),
        .mem_d_req_mask             ( mem_d_req_mask        ),
        .mem_d_req_data             ( mem_d_req_data        ),

        .mem_d_rsp_vld              ( mem_d_rsp_vld         ),
        .mem_d_rsp_rdy              ( mem_d_rsp_rdy         ),
        .mem_d_rsp_excp             ( mem_d_rsp_excp        ),
        .mem_d_rsp_data             ( mem_d_rsp_data        ),

        // Inst device access.
        .dev_i_req_vld              ( dev_i_req_vld         ),
        .dev_i_req_rdy              ( dev_i_req_rdy         ),
        .dev_i_req_addr             ( dev_i_req_addr        ),

        .dev_i_rsp_vld              ( dev_i_rsp_vld         ),
        .dev_i_rsp_rdy              ( dev_i_rsp_rdy         ),
        .dev_i_rsp_excp             ( dev_i_rsp_excp        ),
        .dev_i_rsp_data             ( dev_i_rsp_data        ),

        // Data device access.
        .dev_d_req_vld              ( dev_d_req_vld         ),
        .dev_d_req_rdy              ( dev_d_req_rdy         ),
        .dev_d_req_read             ( dev_d_req_read        ),
        .dev_d_req_addr             ( dev_d_req_addr        ),
        .dev_d_req_mask             ( dev_d_req_mask        ),
        .dev_d_req_data             ( dev_d_req_data        ),

        .dev_d_rsp_vld              ( dev_d_rsp_vld         ),
        .dev_d_rsp_rdy              ( dev_d_rsp_rdy         ),
        .dev_d_rsp_excp             ( dev_d_rsp_excp        ),
        .dev_d_rsp_data             ( dev_d_rsp_data        ),

        // Control & status to SOC.
        .tmr_irq_clr                ( tmr_irq_clr           ),
        .core_lp_mode               ( core_lp_mode          ),

        // Control & status from SOC.
        .irq_from_nmi               ( nmi                   ),
        .irq_from_ext               ( ext_irq               ),
        .irq_from_sft               ( sft_irq               ),
        .irq_from_tmr               ( tmr_irq               ),
        .cnt_from_tmr               ( tmr_val               )
    );

    //-------------------------------------------------------
    // Memory subsys.
    generate
        if (USE_INST_DAM) begin: gen_inst_dam_port
            assign dam_i_req_vld  = mem_i_req_vld;
            assign mem_i_req_rdy  = dam_i_req_rdy;
            assign dam_i_req_read = 1'b1;
            assign dam_i_req_addr = mem_i_req_addr[DAM_PORT_AW-1:0];
            assign dam_i_req_mask = {DAM_PORT_MW{1'b0}};
            assign dam_i_req_data = {DAM_PORT_MW{1'b0}};

            assign mem_i_rsp_vld  = dam_i_rsp_vld;
            assign dam_i_rsp_rdy  = mem_i_rsp_rdy;
            assign mem_i_rsp_excp = dam_i_rsp_excp;
            assign mem_i_rsp_data = dam_i_rsp_data;
        end
        else begin: rmv_inst_dam_port
            assign dam_i_req_vld  = 1'b0;
            assign dam_i_req_read = 1'b0;
            assign dam_i_req_addr = {DAM_PORT_AW{1'b0}};
            assign dam_i_req_mask = {DAM_PORT_MW{1'b0}};
            assign dam_i_req_data = {DAM_PORT_MW{1'b0}};
            assign dam_i_rsp_rdy  = 1'b0;
        end
    endgenerate

    generate
        if (USE_DATA_DAM) begin: gen_data_dam_port
            assign dam_d_req_vld  = mem_d_req_vld;
            assign mem_d_req_rdy  = dam_d_req_rdy;
            assign dam_d_req_read = mem_d_req_read;
            assign dam_d_req_addr = mem_d_req_addr[DAM_PORT_AW-1:0];
            assign dam_d_req_mask = mem_d_req_mask;
            assign dam_d_req_data = mem_d_req_data;

            assign mem_d_rsp_vld  = dam_d_rsp_vld;
            assign dam_d_rsp_rdy  = mem_d_rsp_rdy;
            assign mem_d_rsp_excp = dam_d_rsp_excp;
            assign mem_d_rsp_data = dam_d_rsp_data;
        end
        else begin: rmv_data_dam_port
            assign dam_d_req_vld  = 1'b0;
            assign dam_d_req_read = 1'b0;
            assign dam_d_req_addr = {DAM_PORT_AW{1'b0}};
            assign dam_d_req_mask = {DAM_PORT_MW{1'b0}};
            assign dam_d_req_data = {DAM_PORT_MW{1'b0}};
            assign dam_d_rsp_rdy  = 1'b0;
        end
    endgenerate

    generate
        if (USE_INST_DAM | USE_DATA_DAM) begin: gen_dam
            uv_dam
            #(  
                .PORT_AW                        ( DAM_PORT_AW       ),
                .PORT_DW                        ( DAM_PORT_DW       ),
                .PORT_MW                        ( DAM_PORT_MW       ),
                .SRAM_DP                        ( DAM_SRAM_DP       )
            )
            u_dam
            (
                .clk                            ( core_clk          ),
                .rst_n                          ( core_rst_n        ),

                .port_a_req_vld                 ( dam_i_req_vld     ),
                .port_a_req_rdy                 ( dam_i_req_rdy     ),
                .port_a_req_read                ( dam_i_req_read    ),
                .port_a_req_addr                ( dam_i_req_addr    ),
                .port_a_req_mask                ( dam_i_req_mask    ),
                .port_a_req_data                ( dam_i_req_data    ),

                .port_a_rsp_vld                 ( dam_i_rsp_vld     ),
                .port_a_rsp_rdy                 ( dam_i_rsp_rdy     ),
                .port_a_rsp_excp                ( dam_i_rsp_excp    ),
                .port_a_rsp_data                ( dam_i_rsp_data    ),

                .port_b_req_vld                 ( dam_d_req_vld     ),
                .port_b_req_rdy                 ( dam_d_req_rdy     ),
                .port_b_req_read                ( dam_d_req_read    ),
                .port_b_req_addr                ( dam_d_req_addr    ),
                .port_b_req_mask                ( dam_d_req_mask    ),
                .port_b_req_data                ( dam_d_req_data    ),

                .port_b_rsp_vld                 ( dam_d_rsp_vld     ),
                .port_b_rsp_rdy                 ( dam_d_rsp_rdy     ),
                .port_b_rsp_excp                ( dam_d_rsp_excp    ),
                .port_b_rsp_data                ( dam_d_rsp_data    )
            );
        end
        else begin: gen_mem_subsys
            // TODO.
        end
    endgenerate

    //-------------------------------------------------------
    // DMA subsys.
    // TODO.

    //-------------------------------------------------------
    // Device subsys.
    uv_dev_subsys
    #(
        .ALEN                       ( ALEN                  ),
        .DLEN                       ( XLEN                  ),
        .MLEN                       ( MLEN                  ),
        .IO_NUM                     ( IO_NUM                )
    )
    u_dev_subsys
    (
        .sys_clk                    ( sys_clk               ),
        .aon_clk                    ( aon_clk               ),
        .low_clk                    ( low_clk               ),
        .sys_rst_n                  ( sys_rst_n             ),
        .por_rst_n                  ( por_rst_n             ),

        // Inst device access.
        .dev_i_req_vld              ( dev_i_req_vld         ),
        .dev_i_req_rdy              ( dev_i_req_rdy         ),
        .dev_i_req_addr             ( dev_i_req_addr        ),
        .dev_i_rsp_vld              ( dev_i_rsp_vld         ),
        .dev_i_rsp_rdy              ( dev_i_rsp_rdy         ),
        .dev_i_rsp_excp             ( dev_i_rsp_excp        ),
        .dev_i_rsp_data             ( dev_i_rsp_data        ),

        // Data device access.
        .dev_d_req_vld              ( dev_d_req_vld         ),
        .dev_d_req_rdy              ( dev_d_req_rdy         ),
        .dev_d_req_read             ( dev_d_req_read        ),
        .dev_d_req_addr             ( dev_d_req_addr        ),
        .dev_d_req_mask             ( dev_d_req_mask        ),
        .dev_d_req_data             ( dev_d_req_data        ),
        .dev_d_rsp_vld              ( dev_d_rsp_vld         ),
        .dev_d_rsp_rdy              ( dev_d_rsp_rdy         ),
        .dev_d_rsp_excp             ( dev_d_rsp_excp        ),
        .dev_d_rsp_data             ( dev_d_rsp_data        ),

        // DMA device access.
        .dma_req_vld                ( 1'b0                  ),
        .dma_req_rdy                (                       ),
        .dma_req_read               ( 1'b0                  ),
        .dma_req_addr               ( {ALEN{1'b0}}          ),
        .dma_req_mask               ( {MLEN{1'b0}}          ),
        .dma_req_data               ( {XLEN{1'b0}}          ),
        .dma_rsp_vld                (                       ),
        .dma_rsp_rdy                ( 1'b0                  ),
        .dma_rsp_excp               (                       ),
        .dma_rsp_data               (                       ),

        // Debug device access.
        .dbg_req_vld                ( 1'b0                  ),
        .dbg_req_rdy                (                       ),
        .dbg_req_read               ( 1'b0                  ),
        .dbg_req_addr               ( {ALEN{1'b0}}          ),
        .dbg_req_mask               ( {MLEN{1'b0}}          ),
        .dbg_req_data               ( {XLEN{1'b0}}          ),
        .dbg_rsp_vld                (                       ),
        .dbg_rsp_rdy                ( 1'b0                  ),
        .dbg_rsp_excp               (                       ),
        .dbg_rsp_data               (                       ),

        // Control & status with core.
        .tmr_irq_clr                ( tmr_irq_clr           ),
        .rst_vec                    ( rst_vec               ),
        .ext_irq                    ( ext_irq               ),
        .sft_irq                    ( sft_irq               ),
        .tmr_irq                    ( tmr_irq               ),
        .tmr_val                    ( tmr_val               ),

        // Control & status with SOC.
        .slc_rst_n                  ( slc_rst_n             ),
        .wdt_rst_n                  ( wdt_rst_n             ),

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
        
        .gpio_pu                    ( gpio_pu               ),
        .gpio_pd                    ( gpio_pd               ),
        .gpio_ie                    ( gpio_ie               ),
        .gpio_in                    ( gpio_in               ),
        .gpio_oe                    ( gpio_oe               ),
        .gpio_out                   ( gpio_out              )
    );

endmodule

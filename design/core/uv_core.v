//************************************************************
// See LICENSE for license details.
//
// Module: uv_core
//
// Designer: Owen
//
// Description:
//      CPU Core with BIU & Cache.
//************************************************************

`timescale 1ns / 1ps

module uv_core
#(  
    parameter ARCH_ID               = 64'h235,
    parameter IMPL_ID               = 1,
    parameter HART_ID               = 0,
    parameter VENDOR_ID             = 0,
    parameter ALEN                  = 32,       // Address bit width.
    parameter ILEN                  = 32,       // Instruction bit width.
    parameter XLEN                  = 32,       // Core bit width.
    parameter MLEN                  = XLEN / 8, // Mask bit width.
    parameter MEM_BASE_LSB          = 31,       // LSB of base address for memory bus access.
    parameter MEM_BASE_ADDR         = 1'h1,     // 32'h80000000~32'hffffffff for memory in default.
    parameter DEV_BASE_LSB          = 31,       // LSB of base address for device bus access. 
    parameter DEV_BASE_ADDR         = 1'h0,     // 32'h00000000~32'h7fffffff for device in default.
    parameter USE_INST_DAM          = 1'b1,     // Use Direct Accessed Memory for instruction rather than icache.
    parameter USE_DATA_DAM          = 1'b1,     // Use Direct Accessed Memory for data rather than dcache.
    parameter INST_MEM_DW           = ILEN,     // IDAM data width or icache line size.
    parameter INST_MEM_MW           = MLEN,     // Unused now.
    parameter DATA_MEM_DW           = XLEN,     // DDAM data width or dcache line size.
    parameter DATA_MEM_MW           = MLEN      // Byte strobe (mask) width for DDAM or dcache.
)
(
    input                           clk,
    input                           rst_n,

    // Reset vector from system.
    input  [ALEN-1:0]               rst_vec,
    
    // Inst memory access.
    output                          mem_i_req_vld,
    input                           mem_i_req_rdy,
    output [ALEN-1:0]               mem_i_req_addr,

    input                           mem_i_rsp_vld,
    output                          mem_i_rsp_rdy,
    input  [1:0]                    mem_i_rsp_excp,
    input  [INST_MEM_DW-1:0]        mem_i_rsp_data,
    
    // Data memory access.
    output                          mem_d_req_vld,
    input                           mem_d_req_rdy,
    output                          mem_d_req_read,
    output [ALEN-1:0]               mem_d_req_addr,
    output [DATA_MEM_MW-1:0]        mem_d_req_mask,
    output [DATA_MEM_DW-1:0]        mem_d_req_data,

    input                           mem_d_rsp_vld,
    output                          mem_d_rsp_rdy,
    input  [1:0]                    mem_d_rsp_excp,
    input  [DATA_MEM_DW-1:0]        mem_d_rsp_data,

    // Inst system access.
    output                          dev_i_req_vld,
    input                           dev_i_req_rdy,
    output [ALEN-1:0]               dev_i_req_addr,

    input                           dev_i_rsp_vld,
    output                          dev_i_rsp_rdy,
    input  [1:0]                    dev_i_rsp_excp,
    input  [XLEN-1:0]               dev_i_rsp_data,

    // Data system access.
    output                          dev_d_req_vld,
    input                           dev_d_req_rdy,
    output                          dev_d_req_read,
    output [ALEN-1:0]               dev_d_req_addr,
    output [MLEN-1:0]               dev_d_req_mask,
    output [XLEN-1:0]               dev_d_req_data,

    input                           dev_d_rsp_vld,
    output                          dev_d_rsp_rdy,
    input  [1:0]                    dev_d_rsp_excp,
    input  [XLEN-1:0]               dev_d_rsp_data,

    // Control & status to SOC.
    output                          tmr_irq_clr,
    output                          core_lp_mode,

    // Control & status from SOC.
    input                           irq_from_nmi,
    input                           irq_from_ext,
    input                           irq_from_sft,
    input                           irq_from_tmr,
    input  [63:0]                   cnt_from_tmr
);

    localparam UDLY                 = 1;

    wire                            if_req_vld;
    wire                            if_req_rdy;
    wire [ALEN-1:0]                 if_req_addr;

    wire                            if_rsp_vld;
    wire                            if_rsp_rdy;
    wire [1:0]                      if_rsp_excp;
    wire [ILEN-1:0]                 if_rsp_data;

    wire                            ls_req_vld;
    wire                            ls_req_rdy;
    wire                            ls_req_read;
    wire [ALEN-1:0]                 ls_req_addr;
    wire [MLEN-1:0]                 ls_req_mask;
    wire [XLEN-1:0]                 ls_req_data;

    wire                            ls_rsp_vld;
    wire                            ls_rsp_rdy;
    wire [1:0]                      ls_rsp_excp;
    wire [XLEN-1:0]                 ls_rsp_data;

    wire                            inst_mem_req_vld;
    wire                            inst_mem_req_rdy;
    wire [ALEN-1:0]                 inst_mem_req_addr;

    wire                            inst_mem_rsp_vld;
    wire                            inst_mem_rsp_rdy;
    wire [1:0]                      inst_mem_rsp_excp;
    wire [ILEN-1:0]                 inst_mem_rsp_data;

    wire                            data_mem_req_vld;
    wire                            data_mem_req_rdy;
    wire                            data_mem_req_read;
    wire [ALEN-1:0]                 data_mem_req_addr;
    wire [MLEN-1:0]                 data_mem_req_mask;
    wire [XLEN-1:0]                 data_mem_req_data;

    wire                            data_mem_rsp_vld;
    wire                            data_mem_rsp_rdy;
    wire [1:0]                      data_mem_rsp_excp;
    wire [XLEN-1:0]                 data_mem_rsp_data;

    wire                            fence_inst;
    wire                            fence_data;
    wire [3:0]                      fence_pred;
    wire [3:0]                      fence_succ;
    wire                            fence_done;

    assign core_lp_mode = 1'b0;

    // Micro-core.
    uv_ucore
    #(
        .ARCH_ID                    ( ARCH_ID               ),
        .IMPL_ID                    ( IMPL_ID               ),
        .HART_ID                    ( HART_ID               ),
        .VENDOR_ID                  ( VENDOR_ID             ),
        .ALEN                       ( ALEN                  ),
        .ILEN                       ( ILEN                  ),
        .XLEN                       ( XLEN                  ),
        .MLEN                       ( MLEN                  )
    )
    u_ucore
    (
        .clk                        ( clk                   ),
        .rst_n                      ( rst_n                 ),

        // Reset vector from system.
        .rst_vec                    ( rst_vec               ),
        
        // Inst memory access.
        .if_req_vld                 ( if_req_vld            ),
        .if_req_rdy                 ( if_req_rdy            ),
        .if_req_addr                ( if_req_addr           ),

        .if_rsp_vld                 ( if_rsp_vld            ),
        .if_rsp_rdy                 ( if_rsp_rdy            ),
        .if_rsp_excp                ( if_rsp_excp           ),
        .if_rsp_data                ( if_rsp_data           ),
        
        // Load & store access.
        .ls_req_vld                 ( ls_req_vld            ),
        .ls_req_rdy                 ( ls_req_rdy            ),
        .ls_req_read                ( ls_req_read           ),
        .ls_req_addr                ( ls_req_addr           ),
        .ls_req_mask                ( ls_req_mask           ),
        .ls_req_data                ( ls_req_data           ),

        .ls_rsp_vld                 ( ls_rsp_vld            ),
        .ls_rsp_rdy                 ( ls_rsp_rdy            ),
        .ls_rsp_excp                ( ls_rsp_excp           ),
        .ls_rsp_data                ( ls_rsp_data           ),

        // Control & status with SOC.
        .tmr_irq_clr                ( tmr_irq_clr           ),
        .irq_from_nmi               ( irq_from_nmi          ),
        .irq_from_ext               ( irq_from_ext          ),
        .irq_from_sft               ( irq_from_sft          ),
        .irq_from_tmr               ( irq_from_tmr          ),
        .cnt_from_tmr               ( cnt_from_tmr          ),
        
        // To flush instruction channel.
        .fence_inst                 ( fence_inst            ),

        // To flush data channel.
        .fence_data                 ( fence_data            ),
        .fence_pred                 ( fence_pred            ),
        .fence_succ                 ( fence_succ            ),
        .fence_done                 ( fence_done            )
    );

    // Bus interface unit.
    uv_biu
    #(
        .ALEN                       ( ALEN                  ),
        .DLEN                       ( XLEN                  ),
        .MLEN                       ( MLEN                  ),
        .MEM_BASE_LSB               ( MEM_BASE_LSB          ),
        .MEM_BASE_ADDR              ( MEM_BASE_ADDR         ),
        .DEV_BASE_LSB               ( DEV_BASE_LSB          ),
        .DEV_BASE_ADDR              ( DEV_BASE_ADDR         )
    )
    u_biu
    (
        .clk                        ( clk                   ),
        .rst_n                      ( rst_n                 ),

        // Inst fetching from ucore.
        .if_req_vld                 ( if_req_vld            ),
        .if_req_rdy                 ( if_req_rdy            ),
        .if_req_addr                ( if_req_addr           ),

        .if_rsp_vld                 ( if_rsp_vld            ),
        .if_rsp_rdy                 ( if_rsp_rdy            ),
        .if_rsp_excp                ( if_rsp_excp           ),
        .if_rsp_data                ( if_rsp_data           ),

        // Load-store from ucore.
        .ls_req_vld                 ( ls_req_vld            ),
        .ls_req_rdy                 ( ls_req_rdy            ),
        .ls_req_read                ( ls_req_read           ),
        .ls_req_addr                ( ls_req_addr           ),
        .ls_req_mask                ( ls_req_mask           ),
        .ls_req_data                ( ls_req_data           ),

        .ls_rsp_vld                 ( ls_rsp_vld            ),
        .ls_rsp_rdy                 ( ls_rsp_rdy            ),
        .ls_rsp_excp                ( ls_rsp_excp           ),
        .ls_rsp_data                ( ls_rsp_data           ),

        // Access to ICache.
        .mem_i_req_vld              ( inst_mem_req_vld      ),
        .mem_i_req_rdy              ( inst_mem_req_rdy      ),
        .mem_i_req_addr             ( inst_mem_req_addr     ),

        .mem_i_rsp_vld              ( inst_mem_rsp_vld      ),
        .mem_i_rsp_rdy              ( inst_mem_rsp_rdy      ),
        .mem_i_rsp_excp             ( inst_mem_rsp_excp     ),
        .mem_i_rsp_data             ( inst_mem_rsp_data     ),

        // Access to DCache.
        .mem_d_req_vld              ( data_mem_req_vld      ),
        .mem_d_req_rdy              ( data_mem_req_rdy      ),
        .mem_d_req_read             ( data_mem_req_read     ),
        .mem_d_req_addr             ( data_mem_req_addr     ),
        .mem_d_req_mask             ( data_mem_req_mask     ),
        .mem_d_req_data             ( data_mem_req_data     ),

        .mem_d_rsp_vld              ( data_mem_rsp_vld      ),
        .mem_d_rsp_rdy              ( data_mem_rsp_rdy      ),
        .mem_d_rsp_excp             ( data_mem_rsp_excp     ),
        .mem_d_rsp_data             ( data_mem_rsp_data     ),

        // Access to device bus (inst channel).
        .dev_i_req_vld              ( dev_i_req_vld         ),
        .dev_i_req_rdy              ( dev_i_req_rdy         ),
        .dev_i_req_addr             ( dev_i_req_addr        ),

        .dev_i_rsp_vld              ( dev_i_rsp_vld         ),
        .dev_i_rsp_rdy              ( dev_i_rsp_rdy         ),
        .dev_i_rsp_excp             ( dev_i_rsp_excp        ),
        .dev_i_rsp_data             ( dev_i_rsp_data        ),

        // Access to device bus (data channel).
        .dev_d_req_vld              ( dev_d_req_vld         ),
        .dev_d_req_rdy              ( dev_d_req_rdy         ),
        .dev_d_req_read             ( dev_d_req_read        ),
        .dev_d_req_addr             ( dev_d_req_addr        ),
        .dev_d_req_mask             ( dev_d_req_mask        ),
        .dev_d_req_data             ( dev_d_req_data        ),

        .dev_d_rsp_vld              ( dev_d_rsp_vld         ),
        .dev_d_rsp_rdy              ( dev_d_rsp_rdy         ),
        .dev_d_rsp_excp             ( dev_d_rsp_excp        ),
        .dev_d_rsp_data             ( dev_d_rsp_data        )
    );

    generate
        if (USE_INST_DAM) begin: gen_idam_access
            assign mem_i_req_vld            = inst_mem_req_vld;
            assign mem_i_req_addr           = inst_mem_req_addr;
            assign mem_i_rsp_rdy            = inst_mem_rsp_rdy;

            assign inst_mem_req_rdy         = mem_i_req_rdy;
            assign inst_mem_rsp_vld         = mem_i_rsp_vld;
            assign inst_mem_rsp_excp        = mem_i_rsp_excp;
            assign inst_mem_rsp_data        = mem_i_rsp_data;
            
            assign fence_done               = 1'b1;
        end
        else begin: gen_icache
            uv_icache
            #(
                .ALEN                       ( ALEN                  ),
                .DLEN                       ( XLEN                  ),
                .MLEN                       ( MLEN                  ),
                .CACHE_LINE_DLEN            ( INST_MEM_DW           ),
                .CACHE_LINE_MLEN            ( INST_MEM_MW           )
            )
            u_icache
            (
                .clk                        ( clk                   ),
                .rst_n                      ( rst_n                 ),

                // From ucore.
                .cache_req_vld              ( inst_mem_req_vld      ),
                .cache_req_rdy              ( inst_mem_req_rdy      ),
                .cache_req_addr             ( inst_mem_req_addr     ),

                .cache_rsp_vld              ( inst_mem_rsp_vld      ),
                .cache_rsp_rdy              ( inst_mem_rsp_rdy      ),
                .cache_rsp_excp             ( inst_mem_rsp_excp     ),
                .cache_rsp_data             ( inst_mem_rsp_data     ),

                // To membus.
                .mem_req_vld                ( mem_i_req_vld         ),
                .mem_req_rdy                ( mem_i_req_rdy         ),
                .mem_req_addr               ( mem_i_req_addr        ),

                .mem_rsp_vld                ( mem_i_rsp_vld         ),
                .mem_rsp_rdy                ( mem_i_rsp_rdy         ),
                .mem_rsp_excp               ( mem_i_rsp_excp        ),
                .mem_rsp_data               ( mem_i_rsp_data        ),

                .fence_inst                 ( fence_inst            )
            );
        end
    endgenerate

    generate
        if (USE_INST_DAM) begin: gen_ddam_access
            assign mem_d_req_vld            = data_mem_req_vld;
            assign mem_d_req_read           = data_mem_req_read;
            assign mem_d_req_addr           = data_mem_req_addr;
            assign mem_d_req_data           = data_mem_req_data;
            assign mem_d_req_mask           = data_mem_req_mask;
            assign mem_d_rsp_rdy            = data_mem_rsp_rdy;

            assign data_mem_req_rdy         = mem_d_req_rdy;
            assign data_mem_rsp_vld         = mem_d_rsp_vld;
            assign data_mem_rsp_excp        = mem_d_rsp_excp;
            assign data_mem_rsp_data        = mem_d_rsp_data;
        end
        else begin: gen_dcache
            uv_dcache
            #(
                .ALEN                       ( ALEN                  ),
                .DLEN                       ( XLEN                  ),
                .MLEN                       ( MLEN                  ),
                .CACHE_LINE_DLEN            ( DATA_MEM_DW           ),
                .CACHE_LINE_MLEN            ( DATA_MEM_MW           )
            )
            u_dcache
            (
                .clk                        ( clk                   ),
                .rst_n                      ( rst_n                 ),

                // From ucore.
                .cache_req_vld              ( data_mem_req_vld      ),
                .cache_req_rdy              ( data_mem_req_rdy      ),
                .cache_req_addr             ( data_mem_req_addr     ),
                .cache_req_mask             ( data_mem_req_mask     ),
                .cache_req_data             ( data_mem_req_data     ),

                .cache_rsp_vld              ( data_mem_rsp_vld      ),
                .cache_rsp_rdy              ( data_mem_rsp_rdy      ),
                .cache_rsp_excp             ( data_mem_rsp_excp     ),
                .cache_rsp_data             ( data_mem_rsp_data     ),

                // To membus.
                .mem_req_vld                ( mem_d_req_vld         ),
                .mem_req_rdy                ( mem_d_req_rdy         ),
                .mem_req_addr               ( mem_d_req_addr        ),
                .mem_req_mask               ( mem_d_req_mask        ),
                .mem_req_data               ( mem_d_req_data        ),

                .mem_rsp_vld                ( mem_d_rsp_vld         ),
                .mem_rsp_rdy                ( mem_d_rsp_rdy         ),
                .mem_rsp_excp               ( mem_d_rsp_excp        ),
                .mem_rsp_data               ( mem_d_rsp_data        ),

                .fence_data                 ( fence_data            ),
                .fence_pred                 ( fence_pred            ),
                .fence_succ                 ( fence_succ            ),
                .fence_done                 ( fence_done            )
            );
        end
    endgenerate

endmodule

//************************************************************
// See LICENSE for license details.
//
// Module: uv_tmr_apb
//
// Designer: Owen
//
// Description:
//      General-purpose Timer with APB bus interface.
//************************************************************

`timescale 1ns / 1ps

module uv_tmr_apb
#(
    parameter ALEN                  = 12,
    parameter DLEN                  = 32,
    parameter MLEN                  = DLEN / 8
)
(
    input                           clk,
    input                           rst_n,

    // Low-speed clock for timer.
    input                           low_clk,

    // APB ports.
    input                           tmr_psel,
    input                           tmr_penable,
    input  [2:0]                    tmr_pprot,
    input  [ALEN-1:0]               tmr_paddr,
    input  [MLEN-1:0]               tmr_pstrb,
    input                           tmr_pwrite,
    input  [DLEN-1:0]               tmr_pwdata,
    output [DLEN-1:0]               tmr_prdata,
    output                          tmr_pready,
    output                          tmr_pslverr,

    // TMR control & status.
    output                          tmr_irq,
    output                          tmr_evt
);

    localparam UDLY                 = 1;
    localparam ADDR_DEC_WIDTH       = ALEN - 2;
    localparam SYNC_STAGE_TO_SYS    = 2;
    localparam SYNC_STAGE_TO_LOW    = 2;

    localparam REG_TMR_CFG          = 0;
    localparam REG_TMR_VAL          = 1;
    localparam REG_TMR_CMP          = 2;
    localparam REG_TMR_CLR          = 3;

    wire [ADDR_DEC_WIDTH-1:0]       dec_addr;

    // At sys clock domain.
    reg  [31:0]                     tmr_cmp_r;
    reg                             tmr_cnt_en_r;
    reg                             tmr_clr_en_r;
    reg                             tmr_evt_en_r;
    reg  [15:0]                     tmr_clk_div_r;
    reg                             tmr_clr_ack_r;

    wire [31:0]                     tmr_val_sync;
    wire                            tmr_clr_req_sync;
    wire                            tmr_val_at_limit_sync;

    // At low clock domain.
    reg  [31:0]                     tmr_val_r;
    reg  [15:0]                     tmr_div_r;
    reg                             tmr_clr_req_r;

    wire [31:0]                     tmr_cmp_sync;
    wire                            tmr_cnt_en_sync;
    wire                            tmr_clr_en_sync;
    wire                            tmr_evt_en_sync;
    wire [15:0]                     tmr_clk_div_sync;
    wire                            tmr_clr_ack_sync;

    wire [31:0]                     tmr_val_add;
    wire                            tmr_val_to_limit;
    wire                            tmr_val_at_limit;

    wire [15:0]                     tmr_div_add;
    wire                            tmr_div_to_limit;

    reg                             tmr_cnt_en_p;
    wire                            tmr_cnt_en_rise;

    // Decoding.
    wire                            tmr_cfg_match;
    wire                            tmr_val_match;
    wire                            tmr_cmp_match;
    wire                            tmr_clr_match;
    wire                            addr_mismatch;

    wire                            tmr_cfg_wr;
    wire                            tmr_val_wr;
    wire                            tmr_cmp_wr;
    wire                            tmr_clr_wr;

    wire                            tmr_cfg_rd;
    wire                            tmr_val_rd;
    wire                            tmr_cmp_rd;

    reg                             rsp_vld_r;
    reg                             rsp_excp_r;
    reg  [DLEN-1:0]                 rsp_data;
    reg  [DLEN-1:0]                 rsp_data_r;

    // Address decoding.
    assign dec_addr                 = tmr_paddr[ALEN-1:2];
    assign tmr_cfg_match            = dec_addr == REG_TMR_CFG[ADDR_DEC_WIDTH-1:0];
    assign tmr_val_match            = dec_addr == REG_TMR_VAL[ADDR_DEC_WIDTH-1:0];
    assign tmr_cmp_match            = dec_addr == REG_TMR_CMP[ADDR_DEC_WIDTH-1:0];
    assign tmr_clr_match            = dec_addr == REG_TMR_CLR[ADDR_DEC_WIDTH-1:0];
    assign addr_mismatch            = dec_addr >  REG_TMR_CLR[ADDR_DEC_WIDTH-1:0];

    assign tmr_cfg_wr               = tmr_psel & (~tmr_penable) & tmr_pwrite & tmr_cfg_match;
    assign tmr_val_wr               = tmr_psel & (~tmr_penable) & tmr_pwrite & tmr_val_match;
    assign tmr_cmp_wr               = tmr_psel & (~tmr_penable) & tmr_pwrite & tmr_cmp_match;
    assign tmr_clr_wr               = tmr_psel & (~tmr_penable) & tmr_pwrite & tmr_clr_match;

    assign tmr_cfg_rd               = tmr_psel & (~tmr_penable) & (~tmr_pwrite) & tmr_cfg_match;
    assign tmr_val_rd               = tmr_psel & (~tmr_penable) & (~tmr_pwrite) & tmr_val_match;
    assign tmr_cmp_rd               = tmr_psel & (~tmr_penable) & (~tmr_pwrite) & tmr_cmp_match;

    assign tmr_val_add              = tmr_val_r + 1'b1;
    assign tmr_val_to_limit         = tmr_cnt_en_sync && tmr_div_to_limit && (tmr_val_add >= tmr_cmp_sync);
    assign tmr_val_at_limit         = tmr_cnt_en_sync && (tmr_val_r >= tmr_cmp_sync);

    assign tmr_div_add              = tmr_div_r + 1'b1;
    assign tmr_div_to_limit         = tmr_div_add >= (tmr_clk_div_sync + 1'b1);
    assign tmr_cnt_en_rise          = tmr_cnt_en_sync & (~tmr_cnt_en_p);

    assign tmr_irq                  = tmr_val_at_limit_sync & (~tmr_evt_en_r);
    assign tmr_evt                  = tmr_val_at_limit_sync & tmr_evt_en_r;

    // Bus response.
    assign tmr_prdata               = rsp_data_r;
    assign tmr_pready               = rsp_vld_r;
    assign tmr_pslverr              = rsp_excp_r;

    // Write registers from bus.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            tmr_cnt_en_r  <= 1'b0;
            tmr_clr_en_r  <= 1'b0;
            tmr_evt_en_r  <= 1'b0;
            tmr_clk_div_r <= 16'b0;
        end
        else begin
            if (tmr_cfg_wr) begin
                tmr_cnt_en_r        <= #UDLY tmr_pstrb[0] ? tmr_pwdata[0]     : tmr_cnt_en_r;
                tmr_clr_en_r        <= #UDLY tmr_pstrb[0] ? tmr_pwdata[1]     : tmr_clr_en_r;
                tmr_evt_en_r        <= #UDLY tmr_pstrb[0] ? tmr_pwdata[2]     : tmr_evt_en_r;
                tmr_clk_div_r[7:0]  <= #UDLY tmr_pstrb[2] ? tmr_pwdata[23:16] : tmr_clk_div_r[7:0];
                tmr_clk_div_r[15:8] <= #UDLY tmr_pstrb[3] ? tmr_pwdata[31:24] : tmr_clk_div_r[15:8];
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            tmr_cmp_r <= 32'b0;
        end
        else begin
            if (tmr_cmp_wr) begin
                tmr_cmp_r[7:0]   <= #UDLY tmr_pstrb[0] ? tmr_pwdata[7:0]   : tmr_cmp_r[7:0];
                tmr_cmp_r[15:8]  <= #UDLY tmr_pstrb[1] ? tmr_pwdata[15:8]  : tmr_cmp_r[15:8];
                tmr_cmp_r[23:16] <= #UDLY tmr_pstrb[2] ? tmr_pwdata[23:16] : tmr_cmp_r[23:16];
                tmr_cmp_r[31:24] <= #UDLY tmr_pstrb[3] ? tmr_pwdata[31:24] : tmr_cmp_r[31:24];
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            tmr_clr_req_r <= 1'b0;
        end
        else begin
            if (tmr_clr_wr) begin
                tmr_clr_req_r <= 1'b1;
            end
            else if (tmr_clr_ack_sync) begin
                tmr_clr_req_r <= 1'b0;
            end
        end
    end

    // Update timer value.
    always @(posedge low_clk or negedge rst_n) begin
        if (~rst_n) begin
            tmr_val_r <= 32'b0;
        end
        else begin
            if (tmr_clr_req_sync) begin
                tmr_val_r <= #UDLY 32'b0;
            end
            else if (tmr_clr_en_sync & tmr_val_to_limit) begin
                tmr_val_r <= #UDLY 32'b0;
            end
            else if (tmr_cnt_en_sync) begin
                tmr_val_r <= #UDLY tmr_val_add;
            end
        end
    end

    always @(posedge low_clk or negedge rst_n) begin
        if (~rst_n) begin
            tmr_div_r <= 16'b0;
        end
        else begin
            if (tmr_cnt_en_rise) begin
                tmr_div_r <= #UDLY 16'b0;
            end
            else if (tmr_cnt_en_sync & tmr_div_to_limit) begin
                tmr_div_r <= #UDLY 16'b0;
            end
            else if (tmr_cnt_en_sync) begin
                tmr_div_r <= #UDLY tmr_div_add;
            end
        end
    end

    always @(posedge low_clk or negedge rst_n) begin
        if (~rst_n) begin
            tmr_cnt_en_p <= 1'b0;
        end
        else begin
            tmr_cnt_en_p <= #UDLY tmr_cnt_en_sync;
        end
    end 

    // Acknowledge to feed request.
    always @(posedge low_clk or negedge rst_n) begin
        if (~rst_n) begin
            tmr_clr_ack_r <= 1'b0;
        end
        else begin
            tmr_clr_ack_r <= #UDLY tmr_clr_req_sync;
        end
    end

    // Buffer bus response.
    always @(*) begin
        case (1'b1)
            tmr_cfg_rd : rsp_data = {{(DLEN-32){1'b0}}, tmr_clk_div_r, 13'b0, tmr_evt_en_r, tmr_clr_en_r, tmr_cnt_en_r};
            tmr_val_rd : rsp_data = {{(DLEN-32){1'b0}}, tmr_val_sync};
            tmr_cmp_rd : rsp_data = {{(DLEN-32){1'b0}}, tmr_cmp_r};
            default    : rsp_data = {DLEN{1'b0}};
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rsp_data_r <= {DLEN{1'b0}};
        end
        else begin
            if (tmr_psel & (~tmr_penable)) begin
                rsp_data_r <= #UDLY rsp_data;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rsp_vld_r <= 1'b0;
        end
        else begin
            if (tmr_psel & (~tmr_penable)) begin
                rsp_vld_r <= #UDLY 1'b1;
            end
            else begin
                rsp_vld_r <= #UDLY 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rsp_excp_r <= 1'b0;
        end
        else begin
            if (tmr_psel & (~tmr_penable) & addr_mismatch) begin
                rsp_excp_r <= #UDLY 1'b1;
            end
            else begin
                rsp_excp_r <= #UDLY 1'b0;
            end
        end
    end

    // Synchronization cross clock domain.
    // LOW -> SYS
    uv_sync
    #(
        .SYNC_WIDTH             ( 32                    ),
        .SYNC_STAGE             ( SYNC_STAGE_TO_SYS     )
    )
    u_tmr_val_sync
    (
        .clk                    ( clk                   ),
        .rst_n                  ( rst_n                 ),
        .in                     ( tmr_val_r             ),                  
        .out                    ( tmr_val_sync          )
    );

    uv_sync
    #(
        .SYNC_WIDTH             ( 1                     ),
        .SYNC_STAGE             ( SYNC_STAGE_TO_SYS     )
    )
    u_tmr_clr_ack_sync
    (
        .clk                    ( clk                   ),
        .rst_n                  ( rst_n                 ),
        .in                     ( tmr_clr_ack_r         ),                  
        .out                    ( tmr_clr_ack_sync      )
    );

    uv_sync
    #(
        .SYNC_WIDTH             ( 1                     ),
        .SYNC_STAGE             ( SYNC_STAGE_TO_SYS     )
    )
    u_tmr_val_at_limit_sync
    (
        .clk                    ( clk                   ),
        .rst_n                  ( rst_n                 ),
        .in                     ( tmr_val_at_limit      ),                  
        .out                    ( tmr_val_at_limit_sync )
    );

    // SYS -> LOW
    uv_sync
    #(
        .SYNC_WIDTH             ( 32                    ),
        .SYNC_STAGE             ( SYNC_STAGE_TO_LOW     )
    )
    u_tmr_cmp_sync
    (
        .clk                    ( low_clk               ),
        .rst_n                  ( rst_n                 ),
        .in                     ( tmr_cmp_r             ),                  
        .out                    ( tmr_cmp_sync          )
    );

    uv_sync
    #(
        .SYNC_WIDTH             ( 1                     ),
        .SYNC_STAGE             ( SYNC_STAGE_TO_LOW     )
    )
    u_tmr_cnt_en_sync
    (
        .clk                    ( low_clk               ),
        .rst_n                  ( rst_n                 ),
        .in                     ( tmr_cnt_en_r          ),                  
        .out                    ( tmr_cnt_en_sync       )
    );

    uv_sync
    #(
        .SYNC_WIDTH             ( 1                     ),
        .SYNC_STAGE             ( SYNC_STAGE_TO_LOW     )
    )
    u_tmr_clr_en_sync
    (
        .clk                    ( low_clk               ),
        .rst_n                  ( rst_n                 ),
        .in                     ( tmr_clr_en_r          ),                  
        .out                    ( tmr_clr_en_sync       )
    );

    uv_sync
    #(
        .SYNC_WIDTH             ( 16                    ),
        .SYNC_STAGE             ( SYNC_STAGE_TO_LOW     )
    )
    u_tmr_clk_div_sync
    (
        .clk                    ( low_clk               ),
        .rst_n                  ( rst_n                 ),
        .in                     ( tmr_clk_div_r         ),                  
        .out                    ( tmr_clk_div_sync      )
    );

    uv_sync
    #(
        .SYNC_WIDTH             ( 1                     ),
        .SYNC_STAGE             ( SYNC_STAGE_TO_LOW     )
    )
    u_tmr_clr_req_sync
    (
        .clk                    ( low_clk               ),
        .rst_n                  ( rst_n                 ),
        .in                     ( tmr_clr_req_r         ),                  
        .out                    ( tmr_clr_req_sync      )
    );

endmodule

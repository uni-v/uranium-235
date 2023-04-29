//************************************************************
// See LICENSE for license details.
//
// Module: uv_gpio_apb
//
// Designer: Owen
//
// Description:
//      General-purpose IO with APB interface.
//************************************************************

`timescale 1ns / 1ps

module uv_gpio_apb
#(
    parameter ALEN                  = 12,
    parameter DLEN                  = 32,
    parameter MLEN                  = DLEN / 8,
    parameter IO_NUM                = 32,
    parameter MUX_IO_NUM            = 10
)
(
    input                           clk,
    input                           rst_n,

    // APB ports.
    input                           gpio_psel,
    input                           gpio_penable,
    input  [2:0]                    gpio_pprot,
    input  [ALEN-1:0]               gpio_paddr,
    input  [MLEN-1:0]               gpio_pstrb,
    input                           gpio_pwrite,
    input  [DLEN-1:0]               gpio_pwdata,
    output [DLEN-1:0]               gpio_prdata,
    output                          gpio_pready,
    output                          gpio_pslverr,

    input                           gpio_mode,

    output [IO_NUM-1:0]             gpio_pu,
    output [IO_NUM-1:0]             gpio_pd,
    output [IO_NUM-1:0]             gpio_ie,
    input  [IO_NUM-1:0]             gpio_in,
    output [IO_NUM-1:0]             gpio_oe,
    output [IO_NUM-1:0]             gpio_out,
    output [IO_NUM-1:0]             gpio_irq
);

    localparam UDLY                 = 1;
    localparam ADDR_DEC_WIDTH       = ALEN - 2;
    localparam INPUT_SYNC_STAGE     = 2;

    localparam REG_GPIO_PULL_UP     = 0;
    localparam REG_GPIO_PULL_DOWN   = 1;
    localparam REG_GPIO_IN_VALUE    = 2;
    localparam REG_GPIO_IN_ENABLE   = 3;
    localparam REG_GPIO_OUT_VALUE   = 4;
    localparam REG_GPIO_OUT_ENABLE  = 5;
    localparam REG_GPIO_IRQ_PEND    = 6;
    localparam REG_GPIO_IRQ_ENABLE  = 7;
    localparam REG_GPIO_ADDR_MAX    = 7;

    genvar i;

    wire [ADDR_DEC_WIDTH-1:0]       dec_addr;

    reg  [31:0]                     pull_up_r;
    reg  [31:0]                     pull_down_r;
    reg  [31:0]                     in_enable_r;
    reg  [31:0]                     out_value_r;
    reg  [31:0]                     out_enable_r;
    reg  [31:0]                     irq_pend_r;
    reg  [31:0]                     irq_enable_r;

    wire [31:0]                     in_value;
    wire [IO_NUM-1:0]               gpio_in_sync;

    wire                            pull_up_match;
    wire                            pull_down_match;
    wire                            in_value_match;
    wire                            in_enable_match;
    wire                            out_value_match;
    wire                            out_enable_match;
    wire                            irq_pend_match;
    wire                            irq_enable_match;
    wire                            addr_mismatch;

    wire                            pull_up_wr;
    wire                            pull_down_wr;
    wire                            in_value_wr;
    wire                            in_enable_wr;
    wire                            out_value_wr;
    wire                            out_enable_wr;
    wire                            irq_pend_wr;
    wire                            irq_enable_wr;

    wire                            pull_up_rd;
    wire                            pull_down_rd;
    wire                            in_value_rd;
    wire                            in_enable_rd;
    wire                            out_value_rd;
    wire                            out_enable_rd;
    wire                            irq_pend_rd;
    wire                            irq_enable_rd;

    // Response.
    reg                             rsp_vld_r;
    reg                             rsp_excp_r;
    reg  [DLEN-1:0]                 rsp_data;
    reg  [DLEN-1:0]                 rsp_data_r;

    // Address decoding.
    assign dec_addr                 = gpio_paddr[ALEN-1:2];
    assign pull_up_match            = dec_addr == REG_GPIO_PULL_UP   [ADDR_DEC_WIDTH-1:0];
    assign pull_down_match          = dec_addr == REG_GPIO_PULL_DOWN [ADDR_DEC_WIDTH-1:0];
    assign in_value_match           = dec_addr == REG_GPIO_IN_VALUE  [ADDR_DEC_WIDTH-1:0];
    assign in_enable_match          = dec_addr == REG_GPIO_IN_ENABLE [ADDR_DEC_WIDTH-1:0];
    assign out_value_match          = dec_addr == REG_GPIO_OUT_VALUE [ADDR_DEC_WIDTH-1:0];
    assign out_enable_match         = dec_addr == REG_GPIO_OUT_ENABLE[ADDR_DEC_WIDTH-1:0];
    assign irq_pend_match           = dec_addr == REG_GPIO_IRQ_PEND  [ADDR_DEC_WIDTH-1:0];
    assign irq_enable_match         = dec_addr == REG_GPIO_IRQ_ENABLE[ADDR_DEC_WIDTH-1:0];
    assign addr_mismatch            = dec_addr >  REG_GPIO_ADDR_MAX  [ADDR_DEC_WIDTH-1:0];

    assign pull_up_wr               = gpio_psel & (~gpio_penable) & gpio_pwrite & pull_up_match   ;
    assign pull_down_wr             = gpio_psel & (~gpio_penable) & gpio_pwrite & pull_down_match ;
    assign in_value_wr              = gpio_psel & (~gpio_penable) & gpio_pwrite & in_value_match  ;
    assign in_enable_wr             = gpio_psel & (~gpio_penable) & gpio_pwrite & in_enable_match ;
    assign out_value_wr             = gpio_psel & (~gpio_penable) & gpio_pwrite & out_value_match ;
    assign out_enable_wr            = gpio_psel & (~gpio_penable) & gpio_pwrite & out_enable_match;
    assign irq_pend_wr              = gpio_psel & (~gpio_penable) & gpio_pwrite & irq_pend_match  ;
    assign irq_enable_wr            = gpio_psel & (~gpio_penable) & gpio_pwrite & irq_enable_match;

    assign pull_up_rd               = gpio_psel & (~gpio_penable) & (~gpio_pwrite) & pull_up_match   ;
    assign pull_down_rd             = gpio_psel & (~gpio_penable) & (~gpio_pwrite) & pull_down_match ;
    assign in_value_rd              = gpio_psel & (~gpio_penable) & (~gpio_pwrite) & in_value_match  ;
    assign in_enable_rd             = gpio_psel & (~gpio_penable) & (~gpio_pwrite) & in_enable_match ;
    assign out_value_rd             = gpio_psel & (~gpio_penable) & (~gpio_pwrite) & out_value_match ;
    assign out_enable_rd            = gpio_psel & (~gpio_penable) & (~gpio_pwrite) & out_enable_match;
    assign irq_pend_rd              = gpio_psel & (~gpio_penable) & (~gpio_pwrite) & irq_pend_match  ;
    assign irq_enable_rd            = gpio_psel & (~gpio_penable) & (~gpio_pwrite) & irq_enable_match;

    // Set GPIO input value.
    assign in_value[IO_NUM-1:0]     = gpio_in_sync;
    generate
        if (IO_NUM < 32) begin: gen_in_sync_pad
            assign in_value[31:IO_NUM] = {(32-IO_NUM){1'b0}};
        end
    endgenerate

    // Bus response.
    assign gpio_prdata              = rsp_data_r;
    assign gpio_pready              = rsp_vld_r;
    assign gpio_pslverr             = rsp_excp_r;

    // GPIO control.
    assign gpio_pu                  = pull_up_r[IO_NUM-1:0];
    assign gpio_pd                  = pull_down_r[IO_NUM-1:0];
    assign gpio_ie                  = in_enable_r[IO_NUM-1:0];
    assign gpio_oe                  = out_enable_r[IO_NUM-1:0];
    assign gpio_out                 = out_value_r[IO_NUM-1:0];
    assign gpio_irq                 = irq_pend_r[IO_NUM-1:0];

    // Write registers from bus.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            pull_up_r <= 32'b0;
        end
        else begin
            if (pull_up_wr) begin
                pull_up_r[7:0]   <= #UDLY gpio_pstrb[0] ? gpio_pwdata[7:0]   : pull_up_r[7:0];
                pull_up_r[15:8]  <= #UDLY gpio_pstrb[1] ? gpio_pwdata[15:8]  : pull_up_r[15:8];
                pull_up_r[23:16] <= #UDLY gpio_pstrb[2] ? gpio_pwdata[23:16] : pull_up_r[23:16];
                pull_up_r[31:24] <= #UDLY gpio_pstrb[3] ? gpio_pwdata[31:24] : pull_up_r[31:24];
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            pull_down_r <= 32'b0;
        end
        else begin
            if (pull_down_wr) begin
                pull_down_r[7:0]   <= #UDLY gpio_pstrb[0] ? gpio_pwdata[7:0]   : pull_down_r[7:0];
                pull_down_r[15:8]  <= #UDLY gpio_pstrb[1] ? gpio_pwdata[15:8]  : pull_down_r[15:8];
                pull_down_r[23:16] <= #UDLY gpio_pstrb[2] ? gpio_pwdata[23:16] : pull_down_r[23:16];
                pull_down_r[31:24] <= #UDLY gpio_pstrb[3] ? gpio_pwdata[31:24] : pull_down_r[31:24];
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            in_enable_r <= 32'b0;
        end
        else begin
            if (in_enable_wr) begin
                in_enable_r[7:0]   <= #UDLY gpio_pstrb[0] ? gpio_pwdata[7:0]   : in_enable_r[7:0];
                in_enable_r[15:8]  <= #UDLY gpio_pstrb[1] ? gpio_pwdata[15:8]  : in_enable_r[15:8];
                in_enable_r[23:16] <= #UDLY gpio_pstrb[2] ? gpio_pwdata[23:16] : in_enable_r[23:16];
                in_enable_r[31:24] <= #UDLY gpio_pstrb[3] ? gpio_pwdata[31:24] : in_enable_r[31:24];
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            out_value_r <= 32'b0;
        end
        else begin
            if (out_value_wr) begin
                out_value_r[7:0]   <= #UDLY gpio_pstrb[0] ? gpio_pwdata[7:0]   : out_value_r[7:0];
                out_value_r[15:8]  <= #UDLY gpio_pstrb[1] ? gpio_pwdata[15:8]  : out_value_r[15:8];
                out_value_r[23:16] <= #UDLY gpio_pstrb[2] ? gpio_pwdata[23:16] : out_value_r[23:16];
                out_value_r[31:24] <= #UDLY gpio_pstrb[3] ? gpio_pwdata[31:24] : out_value_r[31:24];
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            out_enable_r <= 32'b0;
        end
        else begin
            if (out_enable_wr) begin
                out_enable_r[7:0]   <= #UDLY gpio_pstrb[0] ? gpio_pwdata[7:0]   : out_enable_r[7:0];
                out_enable_r[15:8]  <= #UDLY gpio_pstrb[1] ? gpio_pwdata[15:8]  : out_enable_r[15:8];
                out_enable_r[23:16] <= #UDLY gpio_pstrb[2] ? gpio_pwdata[23:16] : out_enable_r[23:16];
                out_enable_r[31:24] <= #UDLY gpio_pstrb[3] ? gpio_pwdata[31:24] : out_enable_r[31:24];
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            irq_enable_r <= 32'b0;
        end
        else begin
            if (irq_enable_wr) begin
                irq_enable_r[7:0]   <= #UDLY gpio_pstrb[0] ? gpio_pwdata[7:0]   : irq_enable_r[7:0];
                irq_enable_r[15:8]  <= #UDLY gpio_pstrb[1] ? gpio_pwdata[15:8]  : irq_enable_r[15:8];
                irq_enable_r[23:16] <= #UDLY gpio_pstrb[2] ? gpio_pwdata[23:16] : irq_enable_r[23:16];
                irq_enable_r[31:24] <= #UDLY gpio_pstrb[3] ? gpio_pwdata[31:24] : irq_enable_r[31:24];
            end
        end
    end

    // Set IRQ pending.
    generate
        for (i = 0; i < 32; i = i + 1) begin: gen_irq_pend
            if (i < MUX_IO_NUM) begin: gen_irq_pend_muxed
                always @(posedge clk or negedge rst_n) begin
                    if (~rst_n) begin
                        irq_pend_r[i] <= 1'b0;
                    end
                    else begin
                        if (gpio_mode & irq_enable_r[i] & in_enable_r[i] & in_value[i]) begin
                            irq_pend_r[i] <= #UDLY 1'b1;
                        end
                        else begin
                            irq_pend_r[i] <= #UDLY 1'b0;
                        end
                    end
                end
            end
            else if (i < IO_NUM) begin: gen_irq_pend_vld
                always @(posedge clk or negedge rst_n) begin
                    if (~rst_n) begin
                        irq_pend_r[i] <= 1'b0;
                    end
                    else begin
                        if (irq_enable_r[i] & in_enable_r[i] & in_value[i]) begin
                            irq_pend_r[i] <= #UDLY 1'b1;
                        end
                        else begin
                            irq_pend_r[i] <= #UDLY 1'b0;
                        end
                    end
                end
            end
            else begin: gen_irq_pend_pad
                always @(posedge clk or negedge rst_n) begin
                    if (~rst_n) begin
                        irq_pend_r[i] <= 1'b0;
                    end
                    else begin
                        irq_pend_r[i] <= #UDLY 1'b0;
                    end
                end
            end
        end
    endgenerate

    // Response buf.
    always @(*) begin
        case (1'b1)
            pull_up_rd    : rsp_data = {{(DLEN-32){1'b0}}, pull_up_r};
            pull_down_rd  : rsp_data = {{(DLEN-32){1'b0}}, pull_down_r};
            in_value_rd   : rsp_data = {{(DLEN-32){1'b0}}, in_value};
            in_enable_rd  : rsp_data = {{(DLEN-32){1'b0}}, in_enable_r};
            out_value_rd  : rsp_data = {{(DLEN-32){1'b0}}, out_value_r};
            out_enable_rd : rsp_data = {{(DLEN-32){1'b0}}, out_enable_r};
            irq_pend_rd   : rsp_data = {{(DLEN-32){1'b0}}, irq_pend_r};
            irq_enable_rd : rsp_data = {{(DLEN-32){1'b0}}, irq_enable_r};
            default       : rsp_data = {DLEN{1'b0}};
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rsp_data_r <= {DLEN{1'b0}};
        end
        else begin
            if (gpio_psel & (~gpio_penable)) begin
                rsp_data_r <= #UDLY rsp_data;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rsp_vld_r <= 1'b0;
        end
        else begin
            if (gpio_psel & (~gpio_penable)) begin
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
            if (gpio_psel & (~gpio_penable) & addr_mismatch) begin
                rsp_excp_r <= #UDLY 1'b1;
            end
            else begin
                rsp_excp_r <= #UDLY 1'b0;
            end
        end
    end

    // Synchronize GPIO input to main clock domain.
    uv_sync
    #(
        .SYNC_WIDTH             ( IO_NUM            ),
        .SYNC_STAGE             ( INPUT_SYNC_STAGE  )
    )
    u_gpio_in_sync
    (
        .clk                    ( clk               ),
        .rst_n                  ( rst_n             ),
        .in                     ( gpio_in           ),                  
        .out                    ( gpio_in_sync      )
    );

endmodule

//************************************************************
// See LICENSE for license details.
//
// Module: uv_spi_rtx
//
// Designer: Owen
//
// Description:
//      RX & TX with serial SPI ports.
//************************************************************

`timescale 1ns / 1ps

module uv_spi_rtx
#(
    parameter CS_NUM = 4
)
(
    input                           clk,
    input                           rst_n,

    // Serial ports.
    output [CS_NUM-1:0]             spi_cs,
    output                          spi_sck,
    output                          spi_mosi,
    input                           spi_miso,

    // Config.
    input  [CS_NUM-1:0]             def_idle,
    input  [CS_NUM-1:0]             spi_mask,
    input                           spi_cpol,
    input                           spi_cpha,
    input                           spi_rxen,
    input  [4:0]                    spi_unit,
    input  [7:0]                    sck_dly,
    input  [15:0]                   clk_div,
    input                           endian,

    // TX data from TXQ.
    input                           tx_rdy,
    output                          tx_vld,
    input  [31:0]                   tx_dat,

    // RX data to RXQ.
    input                           rx_rdy,
    output                          rx_vld,
    output [31:0]                   rx_dat
);

    localparam UDLY                 = 1;
    localparam FSM_SPI_IDLE         = 2'h0;
    localparam FSM_SPI_WARM         = 2'h1;
    localparam FSM_SPI_TRAN         = 2'h2;
    localparam FSM_SPI_COOL         = 2'h3;

    genvar i;

    reg  [1:0]                      cur_state;
    reg  [1:0]                      nxt_state;

    reg                             spi_cs_r;
    reg                             spi_sck_r;
    reg                             spi_mosi_r;

    reg                             tx_vld_r;
    reg                             rx_vld_r;
    reg  [31:0]                     tx_dat_tran_r;
    reg  [31:0]                     rx_dat_recv_r;

    reg  [5:0]                      sck_cnt_r;
    reg  [7:0]                      dly_cnt_r;
    reg  [15:0]                     div_cnt_r;

    wire                            state_idle;
    wire                            state_warm;
    wire                            state_tran;
    wire                            state_cool;

    wire                            tran_rdy;
    wire                            tran_cont;

    wire [5:0]                      sck_cnt_add;
    wire [7:0]                      dly_cnt_add;
    wire [15:0]                     div_cnt_add;

    wire                            sck_cnt_end;
    wire                            dly_cnt_end;
    wire                            div_cnt_end;

    wire [4:0]                      tx_dat_sft_bits;
    wire [4:0]                      rx_dat_sft_bits;

    wire [31:0]                     tx_dat_rev;
    wire [31:0]                     tx_dat_rev_sft;
    wire [31:0]                     tx_dat_tran;

    wire [31:0]                     rx_dat_rev;
    wire [31:0]                     rx_dat_rev_sft;
    wire [31:0]                     rx_dat_recv;

    assign state_idle               = cur_state == FSM_SPI_IDLE;
    assign state_warm               = cur_state == FSM_SPI_WARM;
    assign state_tran               = cur_state == FSM_SPI_TRAN;
    assign state_cool               = cur_state == FSM_SPI_COOL;

    assign tran_rdy                 = tx_rdy & rx_rdy;
    assign tran_cont                = state_tran & tran_rdy & sck_cnt_end;

    // Counter status.
    assign sck_cnt_add              = sck_cnt_r + 1'b1;
    assign dly_cnt_add              = dly_cnt_r + 1'b1;
    assign div_cnt_add              = div_cnt_r + 1'b1;

    //assign sck_cnt_end              = sck_cnt_r == {spi_unit, 1'b0};
    assign sck_cnt_end              = sck_cnt_r[5:1] == spi_unit;
    assign dly_cnt_end              = dly_cnt_r == sck_dly;
    assign div_cnt_end              = div_cnt_r == clk_div;

    // Handle TX endian.
    generate
        for (i = 0; i < 32; i = i + 1) begin: gen_dat_bit_rev
            assign tx_dat_rev[i]    = tx_dat[31-i];
            assign rx_dat_rev[i]    = rx_dat_recv_r[31-i];
        end
    endgenerate

    assign tx_dat_sft_bits          = 5'd31 - spi_unit;
    assign rx_dat_sft_bits          = tx_dat_sft_bits;

    assign tx_dat_rev_sft           = tx_dat_rev >> tx_dat_sft_bits;
    assign tx_dat_tran              = endian ? tx_dat_rev_sft : tx_dat;

    assign rx_dat_recv              = spi_cpha ? {rx_dat_recv_r[30:0], spi_miso} : rx_dat_recv_r;
    assign rx_dat_rev_sft           = rx_dat_rev >> rx_dat_sft_bits;

    // Output serial signals.
    assign spi_cs                   = {~spi_mask} | {CS_NUM{spi_cs_r}};
    assign spi_sck                  = spi_sck_r;
    assign spi_mosi                 = spi_mosi_r;

    // Output to queues.
    assign tx_vld                   = tx_vld_r;
    assign rx_vld                   = rx_vld_r;
    assign rx_dat                   = endian ? rx_dat_recv : rx_dat_rev_sft;

    // FSM.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            cur_state <= FSM_SPI_IDLE;
        end
        else begin
            cur_state <= #UDLY nxt_state;
        end
    end

    always @(*) begin
        case (cur_state)
            FSM_SPI_IDLE: begin
                if (tran_rdy) begin
                    nxt_state = FSM_SPI_WARM;
                end
                else begin
                    nxt_state = FSM_SPI_IDLE;
                end
            end
            FSM_SPI_WARM: begin
                if (dly_cnt_end & div_cnt_end) begin
                    nxt_state = FSM_SPI_TRAN;
                end
                else begin
                    nxt_state = FSM_SPI_WARM;
                end
            end
            FSM_SPI_TRAN: begin
                if (sck_cnt_end & div_cnt_end & ~(sck_cnt_r[0] ^ spi_cpha)) begin
                    nxt_state = tran_rdy ? FSM_SPI_TRAN : FSM_SPI_COOL;
                end
                else begin
                    nxt_state = FSM_SPI_TRAN;
                end
            end
            FSM_SPI_COOL: begin
                if (dly_cnt_end & div_cnt_end) begin
                    nxt_state = FSM_SPI_IDLE;
                end
                else begin
                    nxt_state = FSM_SPI_COOL;
                end
            end
            default: begin
                nxt_state = FSM_SPI_IDLE;
            end
        endcase
    end

    // Update SCK delay counter.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            dly_cnt_r <= 8'd0;
        end
        else begin
            case (cur_state)
                FSM_SPI_IDLE: begin
                    if (tran_rdy) begin
                        dly_cnt_r <= #UDLY 8'd0;
                    end
                end
                FSM_SPI_WARM: begin
                    if (~dly_cnt_end) begin
                        dly_cnt_r <= #UDLY dly_cnt_add;
                    end
                end
                FSM_SPI_TRAN: begin
                    if (sck_cnt_end & sck_cnt_r[0] & div_cnt_end & (~tran_rdy)) begin
                        dly_cnt_r <= #UDLY 8'd0;
                    end
                end
                FSM_SPI_COOL: begin
                    if (~dly_cnt_end) begin
                        dly_cnt_r <= #UDLY dly_cnt_add;
                    end
                end
            endcase
        end
    end

    // Update clock divider counter.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            div_cnt_r <= 16'd0;
        end
        else begin
            case (cur_state)
                FSM_SPI_IDLE: begin
                    if (tran_rdy) begin
                        div_cnt_r <= #UDLY 16'd0;
                    end
                end
                FSM_SPI_WARM: begin
                    if (dly_cnt_end & div_cnt_end) begin
                        div_cnt_r <= #UDLY 16'd0;
                    end
                    else if (~div_cnt_end) begin
                        div_cnt_r <= #UDLY div_cnt_add;
                    end
                end
                FSM_SPI_TRAN: begin
                    if (div_cnt_end) begin
                        div_cnt_r <= #UDLY 16'd0;
                    end
                    else begin
                        div_cnt_r <= #UDLY div_cnt_add;
                    end
                end
                FSM_SPI_COOL: begin
                    if (~div_cnt_end) begin
                        div_cnt_r <= #UDLY div_cnt_add;
                    end
                end
            endcase
        end
    end

    // Update SCK edge counter.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            sck_cnt_r <= 6'd0;
        end
        else begin
            case (cur_state)
                FSM_SPI_WARM: begin
                    if (dly_cnt_end & div_cnt_end) begin
                        sck_cnt_r <= #UDLY 6'd0;
                    end
                end
                FSM_SPI_TRAN: begin
                    if (div_cnt_end) begin
                        sck_cnt_r <= #UDLY sck_cnt_end & sck_cnt_r[0] ? 6'd0 : sck_cnt_add;
                    end
                end
            endcase
        end
    end

    // Update CS.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            spi_cs_r <= 1'b1;
        end
        else begin
            if (state_idle) begin
                spi_cs_r <= #UDLY tran_rdy ? ~def_idle : def_idle;
            end
            else if (state_cool & dly_cnt_end & div_cnt_end) begin
                spi_cs_r <= #UDLY def_idle;
            end
        end
    end

    // Update SCK.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            spi_sck_r <= 1'b0;
        end
        else begin
            if (state_idle) begin
                spi_sck_r <= #UDLY spi_cpol;
            end
            else if (state_warm & dly_cnt_end & div_cnt_end) begin
                spi_sck_r <= #UDLY ~spi_sck_r;
            end
            else if (state_tran & div_cnt_end) begin
                spi_sck_r <= #UDLY ~spi_sck_r;
            end
        end
    end

    // Trans data.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            spi_mosi_r <= 1'b0;
        end
        else begin
            if (state_idle & tran_rdy & (~spi_cpha)) begin
                spi_mosi_r <= #UDLY tx_dat_tran[0];
            end
            else if (state_warm & dly_cnt_end & div_cnt_end & spi_cpha) begin
                spi_mosi_r <= #UDLY tx_dat_tran[0];
            end
            else if (tran_cont  & div_cnt_end & ~(sck_cnt_r[0] ^ spi_cpha)) begin
                spi_mosi_r <= #UDLY tx_dat_tran[0];
            end
            else if (state_tran & div_cnt_end & ~(sck_cnt_r[0] ^ spi_cpha)) begin
                spi_mosi_r <= #UDLY tx_dat_tran_r[0];
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            tx_dat_tran_r <= 32'b0;
        end
        else begin
            if (state_idle & tran_rdy & (~spi_cpha)) begin
                tx_dat_tran_r <= #UDLY {1'b0, tx_dat_tran[31:1]};
            end
            else if (state_warm & dly_cnt_end & div_cnt_end & spi_cpha) begin
                tx_dat_tran_r <= #UDLY {1'b0, tx_dat_tran[31:1]};
            end
            else if (tran_cont  & div_cnt_end & ~(sck_cnt_r[0] ^ spi_cpha)) begin
                tx_dat_tran_r <= #UDLY {1'b0, tx_dat_tran[31:1]};
            end
            else if (state_tran & div_cnt_end & ~(sck_cnt_r[0] ^ spi_cpha)) begin
                tx_dat_tran_r <= #UDLY {1'b0, tx_dat_tran_r[31:1]};
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            tx_vld_r <= 1'b0;
        end
        else begin
            if (state_idle & tran_rdy & (~spi_cpha)) begin
                tx_vld_r <= #UDLY 1'b1;
            end
            else if (state_warm & dly_cnt_end & div_cnt_end & spi_cpha) begin
                tx_vld_r <= #UDLY 1'b1;
            end
            else if (tran_cont  & div_cnt_end & ~(sck_cnt_r[0] ^ spi_cpha)) begin
                tx_vld_r <= #UDLY 1'b1;
            end
            else begin
                tx_vld_r <= #UDLY 1'b0;
            end
        end
    end

    // Recv data.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rx_dat_recv_r <= 32'b0;
        end
        else begin
            if (state_idle) begin
                rx_dat_recv_r <= #UDLY 32'b0;
            end
            else if (spi_rxen & (~spi_cpha)) begin
                if (state_warm & dly_cnt_end & div_cnt_end) begin
                    rx_dat_recv_r <= #UDLY {rx_dat_recv_r[30:0], spi_miso};
                end
                else if (state_tran & div_cnt_end & (~sck_cnt_r[0])) begin
                    rx_dat_recv_r <= #UDLY {rx_dat_recv_r[30:0], spi_miso};
                end
            end
            else if (spi_rxen & spi_cpha) begin
                if (state_tran & div_cnt_end & sck_cnt_r[0]) begin
                    rx_dat_recv_r <= #UDLY {rx_dat_recv_r[30:0], spi_miso};
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rx_vld_r <= 1'b0;
        end
        else begin
            if (spi_rxen & sck_cnt_end & sck_cnt_r[0] & div_cnt_end) begin
                rx_vld_r <= #UDLY state_tran | (state_cool & (~spi_cpha));
            end
            else begin
                rx_vld_r <= #UDLY 1'b0;
            end
        end
    end

endmodule

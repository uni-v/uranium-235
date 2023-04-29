//************************************************************
// See LICENSE for license details.
//
// Module: uv_uart_rx
//
// Designer: Owen
//
// Description:
//      UART receiver.
//************************************************************

`timescale 1ns / 1ps

module uv_uart_rx
(
    input                           clk,
    input                           rst_n,

    // Serial receiving.
    input                           uart_rx,

    // Configs.
    input                           rx_en,
    input  [1:0]                    nbits,
    input                           endian,
    input  [15:0]                   clk_div,
    input                           parity_en,
    input  [1:0]                    parity_type,

    // Data.
    input                           rx_rdy,
    output                          rx_vld,
    output [7:0]                    rx_dat
);

    localparam UDLY = 1;
    localparam FSM_UART_RX_IDLE     = 3'h0;
    localparam FSM_UART_RX_START    = 3'h1;
    localparam FSM_UART_RX_DATA     = 3'h2;
    localparam FSM_UART_RX_PARITY   = 3'h3;
    localparam FSM_UART_RX_STOP     = 3'h4;
    
    genvar i;

    reg    [2:0]                    cur_state;
    reg    [2:0]                    nxt_state;

    reg                             rx_vld_r;
    reg    [7:0]                    rx_dat_r;
    reg                             parity_res_r;
    reg                             parity_bit_r;
    reg                             parity_pass;

    reg                             baud_en_r;
    reg    [15:0]                   clk_cnt_r;
    reg    [3:0]                    bit_cnt_r;

    wire   [15:0]                   clk_cnt_add;
    wire                            clk_cnt_end;
    wire                            clk_cnt_half;

    wire   [3:0]                    bit_cnt_add;
    wire                            bit_cnt_end;

    wire   [3:0]                    data_nbits;
    wire   [7:0]                    rx_dat_bit_rev;
    wire   [7:0]                    rx_dat_vld_rev;
    wire   [3:0]                    rx_dat_bit_sft;
    wire   [7:0]                    rx_dat_tran;

    assign clk_cnt_add              = clk_cnt_r + 1'b1;
    assign clk_cnt_end              = clk_cnt_add == clk_div;
    assign clk_cnt_half             = clk_cnt_add == {1'b0, clk_div[15:1]};

    assign bit_cnt_add              = bit_cnt_r + 1'b1;
    assign bit_cnt_end              = bit_cnt_add == data_nbits;

    assign data_nbits               = {2'b0, nbits} + 4'd5;

    assign rx_vld                   = rx_vld_r;
    assign rx_dat                   = rx_dat_tran;

    // Handle RX endian.
    generate
        for (i = 0; i < 8; i = i + 1) begin: gen_tx_dat_bit_rev
            assign rx_dat_bit_rev[i] = rx_dat_r[7-i];
        end
    endgenerate

    assign rx_dat_bit_sft           = 4'd8 - data_nbits;
    assign rx_dat_vld_rev           = rx_dat_bit_rev >> rx_dat_bit_sft;
    assign rx_dat_tran              = endian ? rx_dat_vld_rev : rx_dat_r;

    // FSM.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            cur_state <= FSM_UART_RX_IDLE;
        end
        else begin
            cur_state <= #UDLY nxt_state;
        end
    end

    always @(*) begin
        case (cur_state)
            FSM_UART_RX_IDLE  : begin
                if (rx_en & (~uart_rx)) begin
                    nxt_state = FSM_UART_RX_START;
                end
                else begin
                    nxt_state = FSM_UART_RX_IDLE;
                end
            end
            FSM_UART_RX_START : begin
                if (clk_cnt_end) begin
                    nxt_state = FSM_UART_RX_DATA;
                end
                else begin
                    nxt_state = FSM_UART_RX_START;
                end
            end
            FSM_UART_RX_DATA  : begin
                if (bit_cnt_end & clk_cnt_end) begin
                    nxt_state = parity_en ? FSM_UART_RX_PARITY : FSM_UART_RX_STOP;
                end
                else begin
                    nxt_state = FSM_UART_RX_DATA;
                end
            end
            FSM_UART_RX_PARITY: begin
                if (clk_cnt_end) begin
                    nxt_state = FSM_UART_RX_STOP;
                end
                else begin
                    nxt_state = FSM_UART_RX_PARITY;
                end
            end
            FSM_UART_RX_STOP  : begin
                if (clk_cnt_end) begin
                    nxt_state = FSM_UART_RX_IDLE;
                end
                else begin
                    nxt_state = FSM_UART_RX_STOP;
                end
            end
            default: begin
                nxt_state = FSM_UART_RX_IDLE;
            end
        endcase
    end

    // Enable baud gen.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            baud_en_r <= 1'b0;
        end
        else begin
            case (cur_state)
                FSM_UART_RX_IDLE  : begin
                    if (rx_en & (~uart_rx)) begin
                        baud_en_r <= #UDLY 1'b1;
                    end
                    else begin
                        baud_en_r <= #UDLY 1'b0;
                    end
                end
                FSM_UART_RX_STOP  : begin
                    if (clk_cnt_end) begin
                        baud_en_r <= #UDLY 1'b0;
                    end
                end
            endcase
        end
    end

    // Baud generation.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            clk_cnt_r <= 16'd1;
        end
        else begin
            if (baud_en_r) begin
                if (clk_cnt_end) begin
                    clk_cnt_r <= #UDLY 16'd0;
                end
                else begin
                    clk_cnt_r <= #UDLY clk_cnt_add;
                end
            end
            else begin
                clk_cnt_r <= #UDLY 16'd1;
            end
        end
    end

    // Update data bit counter.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            bit_cnt_r <= 4'd0;
        end
        else begin
            case (cur_state)
                FSM_UART_RX_START: begin
                    if (clk_cnt_end) begin
                        bit_cnt_r <= #UDLY 4'd0;
                    end
                end
                FSM_UART_RX_DATA: begin
                    if (clk_cnt_end) begin
                        bit_cnt_r <= #UDLY bit_cnt_add;
                    end
                end
            endcase
        end
    end

    // Shift received data.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rx_dat_r <= 8'b0;
        end
        else begin
            case (cur_state)
                FSM_UART_RX_START: begin
                    rx_dat_r <= #UDLY 8'b0;
                end
                FSM_UART_RX_DATA: begin
                    if (clk_cnt_half) begin
                        rx_dat_r <= #UDLY {rx_dat_r[6:0], uart_rx};
                    end
                end
            endcase
        end
    end

    // Write received data.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rx_vld_r <= 1'b0;
        end
        else begin
            case (cur_state)
                FSM_UART_RX_IDLE: begin
                    rx_vld_r <= #UDLY 1'b0;
                end
                FSM_UART_RX_STOP: begin
                    if (clk_cnt_end) begin
                        rx_vld_r <= #UDLY parity_en ? parity_pass : 1'b1;
                    end
                end
                default: begin
                    rx_vld_r <= #UDLY 1'b0;
                end
            endcase
        end
    end

    // Calculate parity bit.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            parity_res_r <= 1'b0;
        end
        else begin
            if (cur_state == FSM_UART_RX_START) begin
                parity_res_r <= #UDLY 1'b0;
            end
            else if ((cur_state == FSM_UART_RX_DATA) && clk_cnt_half && parity_en && parity_type[1]) begin
                parity_res_r <= #UDLY parity_res_r ^ uart_rx;
            end
        end
    end

    // Receive parity bit.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            parity_bit_r <= 1'b0;
        end
        else begin
            if (cur_state == FSM_UART_RX_START) begin
                parity_bit_r <= #UDLY 1'b0;
            end
            if ((cur_state == FSM_UART_RX_PARITY) && clk_cnt_half) begin
                parity_bit_r <= #UDLY uart_rx;
            end
        end
    end

    always @(*) begin
        case (parity_type)
            2'b00: parity_pass = ~parity_bit_r;                     // SPACE
            2'b01: parity_pass = parity_bit_r;                      // MARK
            2'b10: parity_pass = ~(parity_res_r ^ parity_bit_r);    // ODD
            2'b11: parity_pass = parity_res_r ^ parity_bit_r;       // EVEN
        endcase
    end

endmodule

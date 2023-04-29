//************************************************************
// See LICENSE for license details.
//
// Module: uv_uart_tx
//
// Designer: Owen
//
// Description:
//      UART transmitter.
//************************************************************

`timescale 1ns / 1ps

module uv_uart_tx
(
    input                           clk,
    input                           rst_n,

    // Serial transmitting.
    output                          uart_tx,

    // Configs.
    input                           tx_en,
    input  [1:0]                    nbits,
    input                           nstop,
    input                           endian,
    input  [15:0]                   clk_div,
    input                           parity_en,
    input  [1:0]                    parity_type,

    // Data.
    input                           tx_rdy,
    output                          tx_vld,
    input  [7:0]                    tx_dat
);

    localparam UDLY = 1;
    localparam FSM_UART_TX_IDLE     = 3'h0;
    localparam FSM_UART_TX_START    = 3'h1;
    localparam FSM_UART_TX_DATA     = 3'h2;
    localparam FSM_UART_TX_PARITY   = 3'h3;
    localparam FSM_UART_TX_STOP0    = 3'h4;
    localparam FSM_UART_TX_STOP1    = 3'h5;
    
    genvar i;

    reg    [2:0]                    cur_state;
    reg    [2:0]                    nxt_state;

    reg                             tx_vld_r;
    reg                             uart_tx_r;
    reg                             parity_res_r;
    reg                             parity_bit;

    reg                             baud_en_r;
    reg    [15:0]                   clk_cnt_r;
    reg    [3:0]                    bit_cnt_r;

    wire   [15:0]                   clk_cnt_add;
    wire                            clk_cnt_end;
    wire                            clk_cnt_half;

    wire   [3:0]                    bit_cnt_add;
    wire                            bit_cnt_end;

    wire   [3:0]                    data_nbits;
    wire   [7:0]                    tx_dat_bit_rev;
    wire   [7:0]                    tx_dat_vld_rev;
    wire   [3:0]                    tx_dat_bit_sft;
    wire   [7:0]                    tx_dat_tran;
    reg    [7:0]                    tx_dat_tran_r;

    assign clk_cnt_add              = clk_cnt_r + 1'b1;
    assign clk_cnt_end              = clk_cnt_add == clk_div;
    assign clk_cnt_half             = clk_cnt_add == {1'b0, clk_div[15:1]};

    assign bit_cnt_add              = bit_cnt_r + 1'b1;
    assign bit_cnt_end              = bit_cnt_add == data_nbits;

    assign data_nbits               = {2'b0, nbits} + 4'd5;

    assign tx_vld                   = tx_vld_r;
    assign uart_tx                  = uart_tx_r;

    // Handle TX endian.
    generate
        for (i = 0; i < 8; i = i + 1) begin: gen_tx_dat_bit_rev
            assign tx_dat_bit_rev[i] = tx_dat[7-i];
        end
    endgenerate

    assign tx_dat_bit_sft           = 4'd8 - data_nbits;
    assign tx_dat_vld_rev           = tx_dat_bit_rev >> tx_dat_bit_sft;
    assign tx_dat_tran              = endian ? tx_dat_vld_rev : tx_dat;

    // FSM.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            cur_state <= FSM_UART_TX_IDLE;
        end
        else begin
            cur_state <= #UDLY nxt_state;
        end
    end

    always @(*) begin
        case (cur_state)
            FSM_UART_TX_IDLE  : begin
                if (tx_en & tx_rdy) begin
                    nxt_state = FSM_UART_TX_START;
                end
                else begin
                    nxt_state = FSM_UART_TX_IDLE;
                end
            end
            FSM_UART_TX_START : begin
                if (clk_cnt_end) begin
                    nxt_state = FSM_UART_TX_DATA;
                end
                else begin
                    nxt_state = FSM_UART_TX_START;
                end
            end
            FSM_UART_TX_DATA  : begin
                if (bit_cnt_end & clk_cnt_end) begin
                    nxt_state = parity_en ? FSM_UART_TX_PARITY : FSM_UART_TX_STOP0;
                end
                else begin
                    nxt_state = FSM_UART_TX_DATA;
                end
            end
            FSM_UART_TX_PARITY: begin
                if (clk_cnt_end) begin
                    nxt_state = FSM_UART_TX_STOP0;
                end
                else begin
                    nxt_state = FSM_UART_TX_PARITY;
                end
            end
            FSM_UART_TX_STOP0 : begin
                if (clk_cnt_end) begin
                    nxt_state = nstop  ? FSM_UART_TX_STOP1 
                              : tx_rdy ? FSM_UART_TX_START : FSM_UART_TX_IDLE;
                end
                else begin
                    nxt_state = FSM_UART_TX_STOP0;
                end
            end
            FSM_UART_TX_STOP1 : begin
                if (clk_cnt_end) begin
                    nxt_state = tx_rdy ? FSM_UART_TX_START : FSM_UART_TX_IDLE;
                end
                else begin
                    nxt_state = FSM_UART_TX_STOP1;
                end
            end
            default: begin
                nxt_state = FSM_UART_TX_IDLE;
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
                FSM_UART_TX_IDLE  : begin
                    if (tx_en & tx_rdy) begin
                        baud_en_r <= #UDLY 1'b1;
                    end
                    else begin
                        baud_en_r <= #UDLY 1'b0;
                    end
                end
                FSM_UART_TX_STOP0 : begin
                    if (clk_cnt_end & (~nstop) & (~tx_rdy)) begin
                        baud_en_r <= #UDLY 1'b0;
                    end
                end
                FSM_UART_TX_STOP1 : begin
                    if (clk_cnt_end & (~tx_rdy)) begin
                        baud_en_r <= #UDLY 1'b0;
                    end
                end
            endcase
        end
    end

    // Baud generation.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            clk_cnt_r <= 16'd0;
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
                clk_cnt_r <= #UDLY 16'd0;
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
                FSM_UART_TX_START: begin
                    if (clk_cnt_end) begin
                        bit_cnt_r <= #UDLY 4'd0;
                    end
                end
                FSM_UART_TX_DATA: begin
                    if (clk_cnt_end) begin
                        bit_cnt_r <= #UDLY bit_cnt_add;
                    end
                end
            endcase
        end
    end

    // Shift transmitted data.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            tx_dat_tran_r <= 8'b0;
        end
        else begin
            case (cur_state)
                FSM_UART_TX_IDLE: begin
                    if (tx_rdy) begin
                        tx_dat_tran_r <= #UDLY tx_dat_tran;
                    end
                end
                FSM_UART_TX_START: begin
                    if (clk_cnt_end) begin
                        tx_dat_tran_r <= #UDLY {1'b0, tx_dat_tran_r[7:1]};
                    end
                end
                FSM_UART_TX_DATA: begin
                    if (clk_cnt_end) begin
                        tx_dat_tran_r <= #UDLY {1'b0, tx_dat_tran_r[7:1]};
                    end
                end
                FSM_UART_TX_STOP0 : begin
                    if (clk_cnt_end & (~nstop) & tx_rdy) begin
                        tx_dat_tran_r <= #UDLY tx_dat_tran;
                    end
                end
                FSM_UART_TX_STOP1 : begin
                    if (clk_cnt_end & tx_rdy) begin
                        tx_dat_tran_r <= #UDLY tx_dat_tran;
                    end
                end
            endcase
        end
    end

    // Read transmitted data.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            tx_vld_r <= 1'b0;
        end
        else begin
            case (cur_state)
                FSM_UART_TX_IDLE: begin
                    if (tx_rdy) begin
                        tx_vld_r <= #UDLY 1'b1;
                    end
                    else begin
                        tx_vld_r <= #UDLY 1'b0;
                    end
                end
                FSM_UART_TX_START: begin
                    tx_vld_r <= #UDLY 1'b0;
                end
                FSM_UART_TX_STOP0 : begin
                    if (clk_cnt_end & (~nstop) & tx_rdy) begin
                        tx_vld_r <= #UDLY 1'b1;
                    end
                end
                FSM_UART_TX_STOP1 : begin
                    if (clk_cnt_end & tx_rdy) begin
                        tx_vld_r <= #UDLY 1'b1;
                    end
                end
                default: begin
                    tx_vld_r <= #UDLY 1'b0;
                end
            endcase
        end
    end

    // Set transmitted bit.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            uart_tx_r <= 1'b1;
        end
        else begin
            case (cur_state)
                FSM_UART_TX_IDLE: begin
                    if (tx_rdy) begin
                        uart_tx_r <= #UDLY 1'b0;
                    end
                end
                FSM_UART_TX_START: begin
                    if (clk_cnt_end) begin
                        uart_tx_r <= #UDLY tx_dat_tran_r[0];
                    end
                end
                FSM_UART_TX_DATA: begin
                    if (bit_cnt_end & clk_cnt_end) begin
                        uart_tx_r <= #UDLY parity_en ? parity_bit : 1'b1;
                    end
                    else if (clk_cnt_end) begin
                        uart_tx_r <= #UDLY tx_dat_tran_r[0];
                    end
                end
                FSM_UART_TX_STOP0 : begin
                    if (clk_cnt_end & (~nstop) & tx_rdy) begin
                        uart_tx_r <= #UDLY 1'b0;
                    end
                end
                FSM_UART_TX_STOP1 : begin
                    if (clk_cnt_end & tx_rdy) begin
                        uart_tx_r <= #UDLY 1'b0;
                    end
                end
                default: begin
                    uart_tx_r <= #UDLY 1'b1;
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
            if (cur_state == FSM_UART_TX_START) begin
                parity_res_r <= #UDLY 1'b0;
            end
            else if ((cur_state == FSM_UART_TX_DATA) && clk_cnt_half && parity_en && parity_type[1]) begin
                parity_res_r <= #UDLY parity_res_r ^ uart_tx_r;
            end
        end
    end

    always @(*) begin
        case (parity_type)
            2'b00: parity_bit = 1'b0;           // SPACE
            2'b01: parity_bit = 1'b1;           // MARK
            2'b10: parity_bit = ~parity_res_r;  // ODD
            2'b11: parity_bit = parity_res_r;   // EVEN
        endcase
    end

endmodule

//************************************************************
// See LICENSE for license details.
//
// Module: uv_i2c_rtx
//
// Designer: Owen
//
// Description:
//      I2C transmitter & receiver.
//************************************************************

`timescale 1ns / 1ps

module uv_i2c_rtx
(
    input                           clk,
    input                           rst_n,

    input                           i2c_scl_in,
    output                          i2c_scl_out,
    output                          i2c_scl_oen,
    input                           i2c_sda_in,
    output                          i2c_sda_out,
    output                          i2c_sda_oen,

    // Control & status.
    input                           i2c_start,
    output                          i2c_busy,
    output                          i2c_nack,
    output                          i2c_nscl,

    // Configs.
    input  [7:0]                    nframes,
    input  [15:0]                   sda_dly,
    input  [15:0]                   clk_div,

    // TX data from TXQ.
    input                           tx_rdy,
    output                          tx_vld,
    input  [7:0]                    tx_dat,

    // RX data to RXQ.
    input                           rx_rdy,
    output                          rx_vld,
    output [7:0]                    rx_dat
);

    localparam UDLY = 1;
    localparam FSM_I2C_IDLE         = 3'h0;
    localparam FSM_I2C_SIZE         = 3'h1;
    localparam FSM_I2C_START        = 3'h2;
    localparam FSM_I2C_ADDR         = 3'h3;
    localparam FSM_I2C_WRITE        = 3'h4;
    localparam FSM_I2C_READ         = 3'h5;
    localparam FSM_I2C_ACK          = 3'h6;
    localparam FSM_I2C_STOP         = 3'h7;

    reg    [2:0]                    cur_state;
    reg    [2:0]                    nxt_state;

    reg                             i2c_scl_out_r;
    reg                             i2c_sda_out_r;
    reg                             i2c_sda_oen_r;

    reg                             i2c_read_r;
    reg    [6:0]                    i2c_addr_r;
    reg    [7:0]                    i2c_size_r;
    reg    [7:0]                    i2c_data_r;
    reg                             i2c_ack_r;

    reg                             i2c_nack_r;
    reg                             i2c_nscl_r;

    reg                             tx_vld_r;
    reg                             rx_vld_r;
    reg    [7:0]                    rx_dat_r;

    reg    [15:0]                   clk_cnt_r;
    reg    [3:0]                    bit_cnt_r;
    reg    [7:0]                    byte_cnt_r;
    reg    [7:0]                    frame_cnt_r;
    reg    [7:0]                    frame_num_r;

    wire   [15:0]                   clk_cnt_add;
    wire                            clk_cnt_end;
    wire                            clk_cnt_half;
    wire                            clk_cnt_quar;
    wire                            clk_cnt_2dly;
    wire                            sda_data_pre;
    wire                            sda_data_pst;

    wire   [3:0]                    bit_cnt_add;
    wire                            bit_cnt_end;

    wire   [3:0]                    byte_cnt_add;
    wire                            byte_cnt_end;

    wire   [3:0]                    frame_cnt_add;
    wire                            frame_cnt_end;

    assign clk_cnt_add              = clk_cnt_r + 1'b1;
    assign clk_cnt_end              = clk_cnt_add == clk_div;
    assign clk_cnt_half             = clk_cnt_add == {1'b0, clk_div[15:1]};
    assign clk_cnt_quar             = clk_cnt_add == {2'b0, clk_div[15:2]};
    assign clk_cnt_2dly             = clk_cnt_r + sda_dly;
    assign sda_data_pre             = clk_cnt_2dly == clk_div;
    assign sda_data_pst             = clk_cnt_add == sda_dly;

    assign bit_cnt_add              = bit_cnt_r + 1'b1;
    assign bit_cnt_end              = bit_cnt_add == 4'd8;

    assign byte_cnt_add             = byte_cnt_r + 1'b1;
    assign byte_cnt_end             = byte_cnt_add == i2c_size_r;

    assign frame_cnt_add            = frame_cnt_r + 1'b1;
    assign frame_cnt_end            = frame_cnt_add == frame_num_r;

    // Set IO signals.
    assign i2c_scl_oen              = 1'b0;  // Always as master.
    assign i2c_scl_out              = i2c_scl_out_r;
    assign i2c_sda_oen              = i2c_sda_oen_r;
    assign i2c_sda_out              = i2c_sda_out_r;

    assign i2c_busy                 = (cur_state == FSM_I2C_IDLE) && (~tx_vld_r);
    assign i2c_nack                 = 1'b0;
    assign i2c_nscl                 = 1'b0;

    // FSM.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            cur_state <= FSM_I2C_IDLE;
        end
        else begin
            cur_state <= #UDLY nxt_state;
        end
    end

    always @(*) begin
        case (cur_state)
            FSM_I2C_IDLE: begin
                if (tx_vld_r) begin
                    nxt_state = FSM_I2C_SIZE;
                end
                else begin
                    nxt_state = FSM_I2C_IDLE;
                end
            end
            FSM_I2C_SIZE: begin
                nxt_state = FSM_I2C_START;
            end
            FSM_I2C_START: begin
                if (clk_cnt_end) begin
                    nxt_state = FSM_I2C_ADDR;
                end
                else begin
                    nxt_state = FSM_I2C_START;
                end
            end
            FSM_I2C_ADDR: begin
                if (bit_cnt_end & clk_cnt_end) begin
                    nxt_state = FSM_I2C_ACK;
                end
                else begin
                    nxt_state = FSM_I2C_ADDR;
                end
            end
            FSM_I2C_WRITE: begin
                if (bit_cnt_end & clk_cnt_end) begin
                    nxt_state = FSM_I2C_ACK;
                end
                else begin
                    nxt_state = FSM_I2C_WRITE;
                end
            end
            FSM_I2C_READ: begin
                if (bit_cnt_end & clk_cnt_end) begin
                    nxt_state = FSM_I2C_ACK;
                end
                else begin
                    nxt_state = FSM_I2C_READ;
                end
            end
            FSM_I2C_ACK: begin
                if (clk_cnt_end) begin
                    if (i2c_ack_r) begin
                        nxt_state = FSM_I2C_STOP;
                    end
                    else if (i2c_size_r == 8'd0) begin
                        nxt_state = FSM_I2C_IDLE;
                    end
                    else if (byte_cnt_end) begin
                        nxt_state = frame_cnt_end ? FSM_I2C_STOP : FSM_I2C_IDLE;
                    end
                    else begin
                        nxt_state = i2c_read_r ? FSM_I2C_READ : FSM_I2C_WRITE;
                    end
                end
                else begin
                    nxt_state = FSM_I2C_ACK;
                end
            end
            FSM_I2C_STOP: begin
                if (clk_cnt_end) begin
                    nxt_state = FSM_I2C_IDLE;
                end
                else begin
                    nxt_state = FSM_I2C_STOP;
                end
            end
            default: begin
                nxt_state = FSM_I2C_IDLE;
            end
        endcase
    end

    // Update clock counter.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            clk_cnt_r <= 16'd0;
        end
        else begin
            if (cur_state == FSM_I2C_SIZE) begin
                clk_cnt_r <= #UDLY 16'd0;
            end
            else if (cur_state != FSM_I2C_IDLE) begin
                if (clk_cnt_end) begin
                    clk_cnt_r <= #UDLY 16'd0;
                end
                else begin
                    clk_cnt_r <= #UDLY clk_cnt_add;
                end
            end
        end
    end

    // Update bit counter.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            bit_cnt_r <= 4'd0;
        end
        else begin
            case (cur_state)
                FSM_I2C_START: begin
                    if (clk_cnt_end) begin
                        bit_cnt_r <= #UDLY 4'd0;
                    end
                end
                FSM_I2C_ADDR: begin
                    if (bit_cnt_end & clk_cnt_end) begin
                        bit_cnt_r <= #UDLY 4'd0;
                    end
                    else if (clk_cnt_end) begin
                        bit_cnt_r <= #UDLY bit_cnt_add;
                    end
                end
                FSM_I2C_WRITE: begin
                    if (bit_cnt_end & clk_cnt_end) begin
                        bit_cnt_r <= #UDLY 4'd0;
                    end
                    else if (clk_cnt_end) begin
                        bit_cnt_r <= #UDLY bit_cnt_add;
                    end
                end
                FSM_I2C_READ: begin
                    if (bit_cnt_end & clk_cnt_end) begin
                        bit_cnt_r <= #UDLY 4'd0;
                    end
                    else if (clk_cnt_end) begin
                        bit_cnt_r <= #UDLY bit_cnt_add;
                    end
                end
            endcase
        end
    end

    // Update byte counter.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            byte_cnt_r <= 8'd0;
        end
        else begin
            case (cur_state)
                FSM_I2C_START: begin
                    if (clk_cnt_end) begin
                        byte_cnt_r <= #UDLY 8'd0;
                    end
                end
                FSM_I2C_ACK: begin
                    if (byte_cnt_end & clk_cnt_end) begin
                        byte_cnt_r <= #UDLY 8'd0;
                    end
                    else if (clk_cnt_end) begin
                        byte_cnt_r <= #UDLY byte_cnt_add;
                    end
                end
            endcase
        end
    end

    // Update frame counter.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            frame_cnt_r <= 8'd0;
            frame_num_r <= 8'd0;
        end
        else begin
            case (cur_state)
                FSM_I2C_IDLE: begin
                    if (i2c_start) begin
                        frame_num_r <= #UDLY nframes;
                    end
                end
                FSM_I2C_ACK: begin
                    if (frame_cnt_end & byte_cnt_end & clk_cnt_end) begin
                        frame_cnt_r <= #UDLY 8'd0;
                    end
                    else if (byte_cnt_end & clk_cnt_end) begin
                        frame_cnt_r <= #UDLY frame_cnt_add;
                    end
                end
            endcase
        end
    end

    // Update controls.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            i2c_read_r <= 1'b0;
            i2c_addr_r <= 7'h0;
            i2c_size_r <= 8'd0;
            i2c_data_r <= 8'h0;
            i2c_ack_r  <= 1'b0;
        end
        else begin
            case (cur_state)
                FSM_I2C_IDLE: begin
                    if (tx_vld_r) begin
                        i2c_read_r <= #UDLY tx_dat[0];
                        i2c_addr_r <= #UDLY tx_dat[7:1];
                    end
                end
                FSM_I2C_SIZE: begin
                    i2c_size_r <= #UDLY tx_dat;
                    i2c_data_r <= #UDLY {i2c_addr_r, i2c_read_r};
                end
                FSM_I2C_START: begin
                    if (sda_data_pre) begin
                        i2c_data_r <= #UDLY {i2c_data_r[6:0], 1'b0};
                    end
                end
                FSM_I2C_ADDR: begin
                    if ((~bit_cnt_end) & sda_data_pre) begin
                        i2c_data_r <= #UDLY {i2c_data_r[6:0], 1'b0};
                    end
                    else if (bit_cnt_end & sda_data_pre) begin
                        if (i2c_read_r) begin
                            i2c_data_r <= #UDLY 8'h0;
                        end
                        else if (i2c_size_r > 8'd0) begin
                            i2c_data_r <= #UDLY tx_dat;
                        end
                    end
                end
                FSM_I2C_WRITE: begin
                    if ((~bit_cnt_end) & sda_data_pre) begin
                        i2c_data_r <= #UDLY {i2c_data_r[6:0], 1'b0};
                    end
                    else if (bit_cnt_end & sda_data_pre & (~byte_cnt_end)) begin
                        i2c_data_r <= #UDLY tx_dat;
                    end
                end
                FSM_I2C_READ: begin
                    if (sda_data_pst) begin
                        i2c_data_r <= #UDLY {i2c_data_r[6:0], 1'b0};
                    end
                    else if (bit_cnt_end & sda_data_pre) begin
                        i2c_data_r <= #UDLY 8'h0;
                    end
                end
                FSM_I2C_ACK: begin
                    if (sda_data_pst) begin
                        i2c_ack_r  <= #UDLY i2c_sda_in;
                    end
                    else if (sda_data_pre & (~i2c_ack_r) & (|i2c_size_r)) begin
                        i2c_data_r <= #UDLY {i2c_data_r[6:0], 1'b0};
                    end
                end
            endcase
        end
    end

    // Read from TX queue.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            tx_vld_r <= 1'b0;
        end
        else begin
            case (cur_state)
                FSM_I2C_IDLE: begin
                    if (i2c_start) begin
                        tx_vld_r <= #UDLY 1'b1;
                    end
                end
                FSM_I2C_SIZE: begin
                    tx_vld_r <= #UDLY 1'b0;
                end
                FSM_I2C_ADDR: begin
                    if (bit_cnt_end & sda_data_pre & (~i2c_read_r)) begin
                        tx_vld_r <= #UDLY 1'b1;
                    end
                    else begin
                        tx_vld_r <= #UDLY 1'b0;
                    end
                end
                FSM_I2C_WRITE: begin
                    if (bit_cnt_end & sda_data_pre) begin
                        tx_vld_r <= #UDLY 1'b1;
                    end
                    else begin
                        tx_vld_r <= #UDLY 1'b0;
                    end
                end
                default: begin
                    tx_vld_r <= #UDLY 1'b0;
                end
            endcase
        end
    end

    // Write to RX queue.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rx_vld_r <= 1'b0;
            rx_dat_r <= 8'h0;
        end
        else begin
            case (cur_state)
                FSM_I2C_READ: begin
                    if (clk_cnt_half) begin
                        rx_vld_r <= #UDLY 1'b1;
                        rx_dat_r <= #UDLY i2c_data_r;
                    end
                    else begin
                        rx_vld_r <= #UDLY 1'b0;
                    end
                end
                default: begin
                    rx_vld_r <= #UDLY 1'b0;
                end
            endcase
        end
    end

    // Control I2C clock.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            i2c_scl_out_r <= 1'b1;
        end
        else begin
            if (cur_state == FSM_I2C_IDLE) begin
                i2c_scl_out_r <= #UDLY 1'b1;
            end
            else begin
                if (clk_cnt_half) begin
                    i2c_scl_out_r <= #UDLY 1'b0;
                end
                else if (clk_cnt_end) begin
                    i2c_scl_out_r <= #UDLY 1'b1;
                end
            end
        end
    end

    // Control I2C data.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            i2c_sda_out_r <= 1'b1;
            i2c_sda_oen_r <= 1'b0;
        end
        else begin
            case (cur_state)
                FSM_I2C_SIZE: begin
                    i2c_sda_out_r <= #UDLY 1'b1;
                    i2c_sda_oen_r <= #UDLY 1'b0;
                end
                FSM_I2C_START: begin
                    if (sda_data_pst) begin
                        i2c_sda_out_r <= #UDLY 1'b0;
                        i2c_sda_oen_r <= #UDLY 1'b0;
                    end
                end
                FSM_I2C_ADDR: begin
                    if ((~bit_cnt_end) & sda_data_pre) begin
                        i2c_sda_out_r <= #UDLY i2c_data_r[7];
                    end
                    else if (bit_cnt_end & sda_data_pre) begin
                        if (i2c_read_r) begin
                            i2c_sda_out_r <= #UDLY 1'b1;
                            i2c_sda_oen_r <= #UDLY 1'b1;
                        end
                    end
                end
                FSM_I2C_WRITE: begin
                    if ((~bit_cnt_end) & sda_data_pre) begin
                        i2c_sda_out_r <= #UDLY i2c_data_r[7];
                    end
                    else if (bit_cnt_end & sda_data_pre) begin
                        i2c_sda_out_r <= #UDLY 1'b1;
                        i2c_sda_oen_r <= #UDLY 1'b1;
                    end
                end
                FSM_I2C_READ: begin
                    if (bit_cnt_end & sda_data_pre) begin
                        i2c_sda_out_r <= #UDLY byte_cnt_end;
                        i2c_sda_oen_r <= #UDLY 1'b0;
                    end
                end
                FSM_I2C_ACK: begin
                    if (sda_data_pre) begin
                        if ((byte_cnt_end || (i2c_size_r == 8'd0)) && frame_cnt_end) begin
                            i2c_sda_out_r <= #UDLY 1'b0;
                            i2c_sda_oen_r <= #UDLY 1'b0;
                        end
                        else if ((~i2c_read_r) & (~byte_cnt_end)) begin
                            i2c_sda_out_r <= #UDLY i2c_data_r[7];
                            i2c_sda_oen_r <= #UDLY 1'b0;
                        end
                    end
                end
                FSM_I2C_STOP: begin
                    if (sda_data_pst) begin
                        i2c_sda_out_r <= #UDLY 1'b1;
                        i2c_sda_oen_r <= #UDLY 1'b0;
                    end
                end
            endcase
        end
    end

endmodule

//************************************************************
// See LICENSE for license details.
//
// Module: uv_sram_bus_ctrl
//
// Designer: Owen
//
// Description:
//      Controller from bus to ram.
//************************************************************

`timescale 1ns / 1ps

module uv_sram_bus_ctrl
#(
    parameter ALEN                  = 32,
    parameter DLEN                  = 32,
    parameter MLEN                  = DLEN / 8,
    parameter SRAM_AW               = 10,
    parameter SRAM_DP               = 2**SRAM_AW
)
(
    input                           clk,
    input                           rst_n,

    input                           sram_req_vld,
    output                          sram_req_rdy,
    input                           sram_req_read,
    input  [ALEN-1:0]               sram_req_addr,
    input  [MLEN-1:0]               sram_req_mask,
    input  [DLEN-1:0]               sram_req_data,

    output                          sram_rsp_vld,
    input                           sram_rsp_rdy,
    output [1:0]                    sram_rsp_excp,
    output [DLEN-1:0]               sram_rsp_data,

    output                          sram_ce,
    output                          sram_we,
    output [SRAM_AW-1:0]            sram_addr,
    output [DLEN-1:0]               sram_wdat,
    output [MLEN-1:0]               sram_mask,
    input  [DLEN-1:0]               sram_rdat
);

    localparam UDLY = 1;
    localparam OFFSET_AW = $clog2(DLEN / 8);

    wire                            addr_overflow;
    wire                            addr_misalign;
    reg                             addr_misalign_r;
    reg                             addr_misalign_rr;

    wire                            misalign_hit;

    wire [OFFSET_AW-1:0]            byte_offset;
    wire [OFFSET_AW-1:0]            diff_offset;
    reg  [OFFSET_AW-1:0]            byte_offset_r;
    reg  [OFFSET_AW-1:0]            diff_offset_r;

    wire [SRAM_AW-1:0]              base_addr;
    wire [SRAM_AW-1:0]              base_addr_add;
    reg  [SRAM_AW-1:0]              base_addr_r;

    wire [DLEN-1:0]                 lsft_wdat;
    wire [MLEN-1:0]                 lsft_mask;
    wire [DLEN-1:0]                 rsft_wdat;
    wire [MLEN-1:0]                 rsft_mask;
    reg                             req_read_r;
    reg  [DLEN-1:0]                 req_data_r;
    reg  [MLEN-1:0]                 req_mask_r;
    reg                             ram_read_p;

    wire [DLEN-1:0]                 rsft_rdat;
    wire [DLEN-1:0]                 lsft_rdat;
    wire [DLEN-1:0]                 comb_rdat;
    reg  [DLEN-1:0]                 rsft_rdat_r;
    reg  [DLEN-1:0]                 rsp_data_r;

    wire                            sram_req_fire;
    wire                            sram_rsp_fire;

    reg                             sram_rsp_vld_r;
    reg                             sram_rsp_excp_r;
    reg  [DLEN-1:0]                 sram_rsp_data_r;

    assign byte_offset              = sram_req_addr[OFFSET_AW-1:0];
    assign diff_offset              = {1'b1, {OFFSET_AW{1'b0}}} - byte_offset;
    assign base_addr                = sram_req_addr[SRAM_AW+OFFSET_AW-1:OFFSET_AW];
    assign base_addr_add            = base_addr + 1'b1;

    assign addr_misalign            = sram_req_vld & (|byte_offset);
    assign addr_overflow            = (sram_req_vld && (base_addr >= SRAM_DP))
                                    | (addr_misalign_r && (base_addr_r >= SRAM_DP));

    assign misalign_hit             = addr_misalign & addr_misalign_r;

    assign lsft_wdat                = sram_req_data << {byte_offset, 3'b0};
    assign lsft_mask                = sram_req_mask << byte_offset;
    assign rsft_wdat                = sram_req_data >> {diff_offset, 3'b0};
    assign rsft_mask                = sram_req_mask >> diff_offset;

    assign sram_ce                  = (sram_req_vld | misalign_hit) & (~addr_overflow);
    assign sram_we                  = misalign_hit ? ~req_read_r : ~sram_req_read;
    assign sram_addr                = misalign_hit ? base_addr_r : base_addr;
    assign sram_wdat                = misalign_hit ? req_data_r  : lsft_wdat;
    assign sram_mask                = misalign_hit ? req_mask_r  : lsft_mask;

    assign rsft_rdat                = sram_rdat >> {byte_offset_r, 3'b0};
    assign lsft_rdat                = sram_rdat << {diff_offset_r, 3'b0};
    assign comb_rdat                = rsft_rdat_r | lsft_rdat;

    assign sram_req_fire            = sram_req_vld & sram_req_rdy;
    assign sram_rsp_fire            = sram_rsp_vld & sram_rsp_rdy;

    assign sram_req_rdy             = ~addr_misalign | addr_misalign_r;
    assign sram_rsp_vld             = sram_rsp_vld_r;
    assign sram_rsp_excp            = {1'b0, sram_rsp_excp_r};
    assign sram_rsp_data            = addr_misalign_rr ? comb_rdat
                                    : ~addr_misalign_r & ram_read_p ? sram_rdat
                                    : rsp_data_r;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            addr_misalign_r <= 1'b0;
        end
        else begin
            if (addr_misalign_r) begin
                addr_misalign_r <= #UDLY 1'b0;
            end
            else if (addr_misalign) begin
                addr_misalign_r <= #UDLY 1'b1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            //addr_misalign_r  <= 1'b0;
            addr_misalign_rr <= 1'b0;
        end
        else begin
            //addr_misalign_r  <= #UDLY addr_misalign;
            addr_misalign_rr <= #UDLY misalign_hit;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            byte_offset_r <= {OFFSET_AW{1'b0}};
        end
        else begin
            if (sram_req_vld) begin
                byte_offset_r <= #UDLY byte_offset;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            diff_offset_r <= {OFFSET_AW{1'b0}};
        end
        else begin
            if (addr_misalign_r) begin
                diff_offset_r <= #UDLY {1'b1, {OFFSET_AW{1'b0}}} - byte_offset_r;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            base_addr_r <= {SRAM_AW{1'b0}};
        end
        else begin
            if (addr_misalign) begin
                base_addr_r <= #UDLY base_addr_add;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            req_read_r <= 1'b0;
        end
        else begin
            if (addr_misalign) begin
                req_read_r <= #UDLY sram_req_read;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            req_data_r <= {DLEN{1'b0}};
            req_mask_r <= {MLEN{1'b0}};
        end
        else begin
            if (addr_misalign) begin
                req_data_r <= #UDLY rsft_wdat;
                req_mask_r <= #UDLY rsft_mask;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            sram_rsp_vld_r <= 1'b0;
        end
        else begin
            if (sram_req_fire) begin
                sram_rsp_vld_r <= #UDLY 1'b1;
            end
            else if (sram_rsp_fire) begin
                sram_rsp_vld_r <= #UDLY 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            sram_rsp_excp_r <= 1'b0;
        end
        else begin
            if (sram_req_fire) begin
                sram_rsp_excp_r <= #UDLY addr_overflow;
            end
            else if (sram_rsp_fire) begin
                sram_rsp_excp_r <= #UDLY 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            ram_read_p <= 1'b0;
        end
        else begin
            ram_read_p <= #UDLY sram_ce & ~sram_we;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rsft_rdat_r <= {DLEN{1'b0}};
        end
        else begin
            if (addr_misalign_r) begin
                rsft_rdat_r <= #UDLY rsft_rdat;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rsp_data_r <= {DLEN{1'b0}};
        end
        else begin
            if (addr_misalign_rr) begin
                rsp_data_r <= #UDLY comb_rdat;
            end
            else if (~addr_misalign_r & ram_read_p) begin
                rsp_data_r <= #UDLY sram_rdat;
            end
        end
    end

endmodule

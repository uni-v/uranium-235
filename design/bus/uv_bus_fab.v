//************************************************************
// See LICENSE for license details.
//
// Module: uv_bus_fab
//
// Designer: Owen
//
// Description:
//      Bus fabric with any number of master ports,
//      and up to 16 slave ports.
//      FIXME: Add alternate pipeline fifo.
//************************************************************

`timescale 1ns / 1ps

module uv_bus_fab
#(
    parameter ALEN                  = 32,
    parameter DLEN                  = 32,
    parameter MLEN                  = DLEN / 8,
    parameter PIPE_STAGE            = 0,    // TODO
    parameter MST_PORT_NUM          = 4,
    parameter SLV_PORT_NUM          = 16,
    parameter SLV0_BASE_LSB         = 28,
    parameter SLV0_BASE_ADDR        = 4'h0,
    parameter SLV1_BASE_LSB         = 28,
    parameter SLV1_BASE_ADDR        = 4'h1,
    parameter SLV2_BASE_LSB         = 28,
    parameter SLV2_BASE_ADDR        = 4'h2,
    parameter SLV3_BASE_LSB         = 28,
    parameter SLV3_BASE_ADDR        = 4'h3,
    parameter SLV4_BASE_LSB         = 28,
    parameter SLV4_BASE_ADDR        = 4'h4,
    parameter SLV5_BASE_LSB         = 28,
    parameter SLV5_BASE_ADDR        = 4'h5,
    parameter SLV6_BASE_LSB         = 28,
    parameter SLV6_BASE_ADDR        = 4'h6,
    parameter SLV7_BASE_LSB         = 28,
    parameter SLV7_BASE_ADDR        = 4'h7,
    parameter SLV8_BASE_LSB         = 28,
    parameter SLV8_BASE_ADDR        = 4'h8,
    parameter SLV9_BASE_LSB         = 28,
    parameter SLV9_BASE_ADDR        = 4'h9,
    parameter SLVA_BASE_LSB         = 28,
    parameter SLVA_BASE_ADDR        = 4'ha,
    parameter SLVB_BASE_LSB         = 28,
    parameter SLVB_BASE_ADDR        = 4'hb,
    parameter SLVC_BASE_LSB         = 28,
    parameter SLVC_BASE_ADDR        = 4'hc,
    parameter SLVD_BASE_LSB         = 28,
    parameter SLVD_BASE_ADDR        = 4'hd,
    parameter SLVE_BASE_LSB         = 28,
    parameter SLVE_BASE_ADDR        = 4'he,
    parameter SLVF_BASE_LSB         = 28,
    parameter SLVF_BASE_ADDR        = 4'hf
)
(
    input                           clk,
    input                           rst_n,

    // Masters.
    input  [MST_PORT_NUM-1:0]       mst_dev_vld,
    input  [MST_PORT_NUM-1:0]       mst_req_vld,
    output [MST_PORT_NUM-1:0]       mst_req_rdy,
    input  [MST_PORT_NUM-1:0]       mst_req_read,
    input  [MST_PORT_NUM*ALEN-1:0]  mst_req_addr,
    input  [MST_PORT_NUM*MLEN-1:0]  mst_req_mask,
    input  [MST_PORT_NUM*DLEN-1:0]  mst_req_data,
    output [MST_PORT_NUM-1:0]       mst_rsp_vld,
    input  [MST_PORT_NUM-1:0]       mst_rsp_rdy,
    output [MST_PORT_NUM*2-1:0]     mst_rsp_excp,
    output [MST_PORT_NUM*DLEN-1:0]  mst_rsp_data,

    // Slaves.
    input  [SLV_PORT_NUM-1:0]       slv_dev_vld,
    output [SLV_PORT_NUM-1:0]       slv_req_vld,
    input  [SLV_PORT_NUM-1:0]       slv_req_rdy,
    output [SLV_PORT_NUM-1:0]       slv_req_read,
    output [SLV_PORT_NUM*ALEN-1:0]  slv_req_addr,
    output [SLV_PORT_NUM*MLEN-1:0]  slv_req_mask,
    output [SLV_PORT_NUM*DLEN-1:0]  slv_req_data,
    input  [SLV_PORT_NUM-1:0]       slv_rsp_vld,
    output [SLV_PORT_NUM-1:0]       slv_rsp_rdy,
    input  [SLV_PORT_NUM*2-1:0]     slv_rsp_excp,
    input  [SLV_PORT_NUM*DLEN-1:0]  slv_rsp_data
);

    localparam UDLY = 1;
    genvar i, j, k;

    // Port matrix.
    wire [ALEN-1:0]                 mst_req_addr_2d [MST_PORT_NUM-1:0];
    wire [MLEN-1:0]                 mst_req_mask_2d [MST_PORT_NUM-1:0];
    wire [DLEN-1:0]                 mst_req_data_2d [MST_PORT_NUM-1:0];
    wire [1:0]                      mst_rsp_excp_2d [MST_PORT_NUM-1:0];
    wire [DLEN-1:0]                 mst_rsp_data_2d [MST_PORT_NUM-1:0];

    wire [ALEN-1:0]                 slv_req_addr_2d [SLV_PORT_NUM-1:0];
    wire [MLEN-1:0]                 slv_req_mask_2d [SLV_PORT_NUM-1:0];
    wire [DLEN-1:0]                 slv_req_data_2d [SLV_PORT_NUM-1:0];
    wire [1:0]                      slv_rsp_excp_2d [SLV_PORT_NUM-1:0];
    wire [DLEN-1:0]                 slv_rsp_data_2d [SLV_PORT_NUM-1:0];

    // Slave selections.
    wire [SLV_PORT_NUM-1:0]         mst_addr_match  [MST_PORT_NUM-1:0];  // mst_addr_match[mst][slv]
    wire [SLV_PORT_NUM-1:0]         mst_sel_to_slv  [MST_PORT_NUM-1:0];  // mst_sel_to_slv[mst][slv]
    wire [MST_PORT_NUM-1:0]         slv_sel_to_mst  [SLV_PORT_NUM-1:0];  // slv_sel_to_mst[slv][mst]
    wire [MST_PORT_NUM-1:0]         mst_acc_fault;
    reg  [MST_PORT_NUM-1:0]         mst_acc_fault_r;

    // Arbiter ports.
    wire [MST_PORT_NUM-1:0]         slv_arb_req     [SLV_PORT_NUM-1:0];  // slv_arb_req[slv][mst]
    wire [MST_PORT_NUM-1:0]         slv_arb_grant   [SLV_PORT_NUM-1:0];  // slv_arb_grant[slv][mst]
    wire [SLV_PORT_NUM-1:0]         mst_arb_grant   [MST_PORT_NUM-1:0];  // mst_arb_grant[mst][slv]
    reg  [MST_PORT_NUM-1:0]         slv_arb_grant_r [SLV_PORT_NUM-1:0];  // mst_arb_grant_r[slv][mst]
    reg  [SLV_PORT_NUM-1:0]         mst_arb_grant_r [MST_PORT_NUM-1:0];  // mst_arb_grant_r[mst][slv]

    // Master-slave locks.
    wire [SLV_PORT_NUM-1:0]         req_lck_to_slv  [MST_PORT_NUM-1:0];  // mst_lck_to_slv[mst][slv]
    wire [SLV_PORT_NUM-1:0]         mst_lck_to_slv  [MST_PORT_NUM-1:0];  // mst_lck_to_slv[mst][slv]
    wire [MST_PORT_NUM-1:0]         slv_lck_to_mst  [SLV_PORT_NUM-1:0];  // slv_lck_to_mst[slv][mst]

    // Master & slave fires.
    wire [MST_PORT_NUM-1:0]         mst_req_fire;
    wire [MST_PORT_NUM-1:0]         mst_rsp_fire;
    wire [SLV_PORT_NUM-1:0]         slv_req_fire;
    wire [SLV_PORT_NUM-1:0]         slv_rsp_fire;

    // Recombine ports from 1D to 2D format.
    generate
        for (i = 0; i < MST_PORT_NUM; i = i + 1) begin: gen_mst_port_2d
            assign mst_req_addr_2d[i] = mst_req_addr[(i+1)*ALEN-1:i*ALEN];
            assign mst_req_mask_2d[i] = mst_req_mask[(i+1)*MLEN-1:i*MLEN];
            assign mst_req_data_2d[i] = mst_req_data[(i+1)*DLEN-1:i*DLEN];
            assign mst_rsp_excp[(i+1)*2-1:i*2]       = mst_rsp_excp_2d[i];
            assign mst_rsp_data[(i+1)*DLEN-1:i*DLEN] = mst_rsp_data_2d[i];
        end
    endgenerate

    generate
        for (i = 0; i < SLV_PORT_NUM; i = i + 1) begin: gen_slv_port_2d
            assign slv_req_addr[(i+1)*ALEN-1:i*ALEN] = slv_req_addr_2d[i];
            assign slv_req_mask[(i+1)*MLEN-1:i*MLEN] = slv_req_mask_2d[i];
            assign slv_req_data[(i+1)*DLEN-1:i*DLEN] = slv_req_data_2d[i];
            assign slv_rsp_excp_2d[i] = slv_rsp_excp[(i+1)*2-1:i*2];
            assign slv_rsp_data_2d[i] = slv_rsp_data[(i+1)*DLEN-1:i*DLEN];
        end
    endgenerate

    // Match slave addresses.
    generate
        for (i = 0; i < MST_PORT_NUM; i = i + 1) begin: gen_mst_addr_match
            if (SLV_PORT_NUM > 0) begin: gen_mst_addr_match_0
                assign mst_addr_match[i][0] = mst_req_addr_2d[i][ALEN-1:SLV0_BASE_LSB] == SLV0_BASE_ADDR;
            end
            if (SLV_PORT_NUM > 1) begin: gen_mst_addr_match_1
                assign mst_addr_match[i][1] = mst_req_addr_2d[i][ALEN-1:SLV1_BASE_LSB] == SLV1_BASE_ADDR;
            end
            if (SLV_PORT_NUM > 2) begin: gen_mst_addr_match_2
                assign mst_addr_match[i][2] = mst_req_addr_2d[i][ALEN-1:SLV2_BASE_LSB] == SLV2_BASE_ADDR;
            end
            if (SLV_PORT_NUM > 3) begin: gen_mst_addr_match_3
                assign mst_addr_match[i][3] = mst_req_addr_2d[i][ALEN-1:SLV3_BASE_LSB] == SLV3_BASE_ADDR;
            end
            if (SLV_PORT_NUM > 4) begin: gen_mst_addr_match_4
                assign mst_addr_match[i][4] = mst_req_addr_2d[i][ALEN-1:SLV4_BASE_LSB] == SLV4_BASE_ADDR;
            end
            if (SLV_PORT_NUM > 5) begin: gen_mst_addr_match_5
                assign mst_addr_match[i][5] = mst_req_addr_2d[i][ALEN-1:SLV5_BASE_LSB] == SLV5_BASE_ADDR;
            end
            if (SLV_PORT_NUM > 6) begin: gen_mst_addr_match_6
                assign mst_addr_match[i][6] = mst_req_addr_2d[i][ALEN-1:SLV6_BASE_LSB] == SLV6_BASE_ADDR;
            end
            if (SLV_PORT_NUM > 7) begin: gen_mst_addr_match_7
                assign mst_addr_match[i][7] = mst_req_addr_2d[i][ALEN-1:SLV7_BASE_LSB] == SLV7_BASE_ADDR;
            end
            if (SLV_PORT_NUM > 8) begin: gen_mst_addr_match_8
                assign mst_addr_match[i][8] = mst_req_addr_2d[i][ALEN-1:SLV8_BASE_LSB] == SLV8_BASE_ADDR;
            end
            if (SLV_PORT_NUM > 9) begin: gen_mst_addr_match_9
                assign mst_addr_match[i][9] = mst_req_addr_2d[i][ALEN-1:SLV9_BASE_LSB] == SLV9_BASE_ADDR;
            end
            if (SLV_PORT_NUM > 10) begin: gen_mst_addr_match_10
                assign mst_addr_match[i][10] = mst_req_addr_2d[i][ALEN-1:SLVA_BASE_LSB] == SLVA_BASE_ADDR;
            end
            if (SLV_PORT_NUM > 11) begin: gen_mst_addr_match_11
                assign mst_addr_match[i][11] = mst_req_addr_2d[i][ALEN-1:SLVB_BASE_LSB] == SLVB_BASE_ADDR;
            end
            if (SLV_PORT_NUM > 12) begin: gen_mst_addr_match_12
                assign mst_addr_match[i][12] = mst_req_addr_2d[i][ALEN-1:SLVC_BASE_LSB] == SLVC_BASE_ADDR;
            end
            if (SLV_PORT_NUM > 13) begin: gen_mst_addr_match_13
                assign mst_addr_match[i][13] = mst_req_addr_2d[i][ALEN-1:SLVD_BASE_LSB] == SLVD_BASE_ADDR;
            end
            if (SLV_PORT_NUM > 14) begin: gen_mst_addr_match_14
                assign mst_addr_match[i][14] = mst_req_addr_2d[i][ALEN-1:SLVE_BASE_LSB] == SLVE_BASE_ADDR;
            end
            if (SLV_PORT_NUM > 15) begin: gen_mst_addr_match_15
                assign mst_addr_match[i][15] = mst_req_addr_2d[i][ALEN-1:SLVF_BASE_LSB] == SLVF_BASE_ADDR;
            end
        end
    endgenerate

    // Select slave for each master.
    generate
        for (i = 0; i < MST_PORT_NUM; i = i + 1) begin: gen_bus_sel_mst
            for (j = 0; j < SLV_PORT_NUM; j = j + 1) begin: gen_bus_sel_slv
                assign mst_sel_to_slv[i][j] = mst_dev_vld[i] & slv_dev_vld[j]
                                            & mst_req_vld[i] & mst_addr_match[i][j]
                                            & (~mst_arb_grant_r[i][j]
                                            | (mst_arb_grant_r[i][j] & slv_rsp_fire[j]));
            end
        end
    endgenerate

    // Transpose selection matrix.
    generate
        for (i = 0; i < SLV_PORT_NUM; i = i + 1) begin: gen_trans_bus_sel_slv
            for (j = 0; j < MST_PORT_NUM; j = j + 1) begin: gen_trans_bus_sel_mst
                assign slv_sel_to_mst[i][j] = mst_sel_to_slv[j][i];
            end
        end
    endgenerate

    // Detect access fault.
    generate
        for (i = 0; i < MST_PORT_NUM; i = i + 1) begin: gen_mst_acc_fault
            assign mst_acc_fault[i] = mst_dev_vld[i] & mst_req_vld[i] & ~(|mst_addr_match[i]);
        end
    endgenerate

    generate
        for (i = 0; i < MST_PORT_NUM; i = i + 1) begin: gen_mst_acc_fault_r
            always @(posedge clk or negedge rst_n) begin
                if (~rst_n) begin
                    mst_acc_fault_r[i] <= 1'b0;
                end
                else begin
                    if (mst_acc_fault[i]) begin
                        mst_acc_fault_r[i] <= #UDLY 1'b1;
                    end
                    else if (mst_rsp_fire[i]) begin
                        mst_acc_fault_r[i] <= #UDLY 1'b0;
                    end
                end
            end
        end
    endgenerate

    // Set arbiters requests.
    //generate
    //    for (i = 0; i < SLV_PORT_NUM; i = i + 1) begin: gen_arb_req
    //        assign slv_arb_req[i] = slv_sel_to_mst[i];
    //    end
    //endgenerate

    generate
        for (i = 0; i < SLV_PORT_NUM; i = i + 1) begin: gen_arb_req
            for (j = 0; j < MST_PORT_NUM; j = j + 1) begin: gen_arb_req_mst
                assign slv_arb_req[i][j] = mst_dev_vld[j] & slv_dev_vld[i]
                                         & mst_req_vld[j] & mst_addr_match[j][i]
                                         & (~(|slv_arb_grant_r[i])
                                         | (|(slv_arb_grant_r[i] & mst_rsp_fire)));
            end
        end
    endgenerate

    // Transpose arbiter grants for masters.
    generate
        for (i = 0; i < MST_PORT_NUM; i = i + 1) begin: gen_trans_arb_grant_mst
            for (j = 0; j < SLV_PORT_NUM; j = j + 1) begin: gen_trans_arb_grant_slv
                assign mst_arb_grant[i][j] = slv_arb_grant[j][i];
            end
        end
    endgenerate

    // Buffer grant status for masters.
    //generate
    //    for (i = 0; i < MST_PORT_NUM; i = i + 1) begin: gen_arb_grant_buf_mst
    //        for (j = 0; j < SLV_PORT_NUM; j = j + 1) begin: gen_arb_grant_buf_slv
    //            always @(posedge clk or negedge rst_n) begin
    //                if (~rst_n) begin
    //                    mst_arb_grant_r[i][j] <= 1'b0;
    //                end
    //                else begin
    //                    if (mst_arb_grant[i][j]) begin
    //                        mst_arb_grant_r[i][j] <= #UDLY 1'b1;
    //                    end
    //                    else if (mst_arb_grant_r[i][j] & slv_rsp_fire[j]) begin
    //                        mst_arb_grant_r[i][j] <= #UDLY 1'b0;
    //                    end
    //                end
    //            end
    //        end
    //    end
    //endgenerate

    generate
        for (i = 0; i < MST_PORT_NUM; i = i + 1) begin: gen_arb_grant_buf
            always @(posedge clk or negedge rst_n) begin
                if (~rst_n) begin
                    mst_arb_grant_r[i] <= {SLV_PORT_NUM{1'b0}};
                end
                else begin
                    if (|mst_arb_grant[i]) begin
                        mst_arb_grant_r[i] <= #UDLY mst_arb_grant[i];
                    end
                    else if (|(mst_arb_grant_r[i] & slv_rsp_fire)) begin
                        mst_arb_grant_r[i] <= #UDLY {SLV_PORT_NUM{1'b0}};
                    end
                end
            end
        end
    endgenerate

    // Transpose grant buffer for slaves.
    generate
        for (i = 0; i < SLV_PORT_NUM; i = i + 1) begin: gen_trans_arb_grant_slv
            for (j = 0; j < MST_PORT_NUM; j = j + 1) begin: gen_trans_arb_grant_mst
                always @(*) begin
                    slv_arb_grant_r[i][j] = mst_arb_grant_r[j][i];
                end
            end
        end
    endgenerate

    //generate
    //    for (i = 0; i < SLV_PORT_NUM; i = i + 1) begin: gen_slv_arb_grant_r
    //        always @(posedge clk or negedge rst_n) begin
    //            if (~rst_n) begin
    //                slv_arb_grant_r[i] <= {MST_PORT_NUM{1'b0}};
    //            end
    //            else begin
    //                if (|slv_arb_grant[i]) begin
    //                    slv_arb_grant_r[i] <= #UDLY slv_arb_grant[i];
    //                end
    //                else if (|(slv_arb_grant_r[i] & mst_rsp_fire)) begin
    //                    slv_arb_grant_r[i] <= #UDLY {MST_PORT_NUM{1'b0}};
    //                end
    //            end
    //        end
    //    end
    //endgenerate

    // Lock master-slave pairs.
    generate
        for (i = 0; i < MST_PORT_NUM; i = i + 1) begin: gen_mst_lck
            //for (j = 0; j < SLV_PORT_NUM; j = j + 1) begin: gen_req_lck
            //    assign req_lck_to_slv[i][j] = mst_arb_grant[i][j]
            //       | (mst_arb_grant_r[i][j] & (~slv_rsp_fire[j]));
            //end
            assign req_lck_to_slv[i] = mst_arb_grant[i]
               | (mst_arb_grant_r[i] & (~(mst_arb_grant_r[i] & slv_rsp_fire)));
            assign mst_lck_to_slv[i] = mst_arb_grant_r[i];
        end
    endgenerate

    generate
        for (i = 0; i < SLV_PORT_NUM; i = i + 1) begin: gen_slv_lck
            //assign slv_lck_to_mst[i] = slv_arb_grant[i] | slv_arb_grant_r[i];
            assign slv_lck_to_mst[i] = slv_arb_grant_r[i];
        end
    endgenerate

    //////////////////
    // Set slv_req_vld.
    wire [SLV_PORT_NUM-1:0]         mst_req_vld_grt [MST_PORT_NUM-1:0];
    wire [MST_PORT_NUM-1:0]         slv_req_vld_grt [SLV_PORT_NUM-1:0];

    generate
        for (i = 0; i < MST_PORT_NUM; i = i + 1) begin: gen_mst_req_vld_granted
            for (j = 0; j < SLV_PORT_NUM; j = j + 1) begin: gen_mst_req_vld_granted_slv
                assign mst_req_vld_grt[i][j] = req_lck_to_slv[i][j] & mst_req_vld[i];
            end
        end
    endgenerate

    generate
        for (i = 0; i < SLV_PORT_NUM; i = i + 1) begin: gen_slv_req_vld_granted
            for (j = 0; j < MST_PORT_NUM; j = j + 1) begin: gen_slv_req_vld_granted_mst
                assign slv_req_vld_grt[i][j] = mst_req_vld_grt[j][i];
            end
        end
    endgenerate

    generate
        for (i = 0; i < SLV_PORT_NUM; i = i + 1) begin: gen_slv_req_vld
            assign slv_req_vld[i] = |slv_req_vld_grt[i];
        end
    endgenerate

    // Set slv_req_read.
    wire [SLV_PORT_NUM-1:0]         mst_req_read_grt [MST_PORT_NUM-1:0];
    wire [MST_PORT_NUM-1:0]         slv_req_read_grt [SLV_PORT_NUM-1:0];

    generate
        for (i = 0; i < MST_PORT_NUM; i = i + 1) begin: gen_mst_req_read_granted
            for (j = 0; j < SLV_PORT_NUM; j = j + 1) begin: gen_mst_req_read_granted_slv
                assign mst_req_read_grt[i][j] = req_lck_to_slv[i][j] & mst_req_read[i];
            end
        end
    endgenerate

    generate
        for (i = 0; i < SLV_PORT_NUM; i = i + 1) begin: gen_slv_req_read_granted
            for (j = 0; j < MST_PORT_NUM; j = j + 1) begin: gen_slv_req_read_granted_mst
                assign slv_req_read_grt[i][j] = mst_req_read_grt[j][i];
            end
        end
    endgenerate

    generate
        for (i = 0; i < SLV_PORT_NUM; i = i + 1) begin: gen_slv_req_read
            assign slv_req_read[i] = |slv_req_read_grt[i];
        end
    endgenerate

    // Set slv_req_addr.
    wire [ALEN-1:0]                 mst_req_addr_grt [MST_PORT_NUM-1:0][SLV_PORT_NUM-1:0];
    wire [MST_PORT_NUM-1:0]         slv_req_addr_grt [SLV_PORT_NUM-1:0][ALEN-1:0];

    generate
        for (i = 0; i < MST_PORT_NUM; i = i + 1) begin: gen_mst_req_addr_granted
            for (j = 0; j < SLV_PORT_NUM; j = j + 1) begin: gen_mst_req_addr_granted_slv
                assign mst_req_addr_grt[i][j] = ({ALEN{req_lck_to_slv[i][j]}} & mst_req_addr_2d[i]);
            end
        end
    endgenerate

    generate
        for (i = 0; i < SLV_PORT_NUM; i = i + 1) begin: gen_slv_req_addr_granted
            for (j = 0; j < ALEN; j = j + 1) begin: gen_slv_req_addr_granted_bit
                for (k = 0; k < MST_PORT_NUM; k = k + 1) begin: gen_slv_req_addr_granted_mst
                    assign slv_req_addr_grt[i][j][k] = mst_req_addr_grt[k][i][j];
                end
            end
        end
    endgenerate

    generate
        for (i = 0; i < SLV_PORT_NUM; i = i + 1) begin: gen_slv_req_addr
            for (j = 0; j < ALEN; j = j + 1) begin: gen_slv_req_addr_bit
                assign slv_req_addr_2d[i][j] = |slv_req_addr_grt[i][j];
            end
        end
    endgenerate

    // Set slv_req_mask.
    wire [MLEN-1:0]                 mst_req_mask_grt [MST_PORT_NUM-1:0][SLV_PORT_NUM-1:0];
    wire [MST_PORT_NUM-1:0]         slv_req_mask_grt [SLV_PORT_NUM-1:0][MLEN-1:0];

    generate
        for (i = 0; i < MST_PORT_NUM; i = i + 1) begin: gen_mst_req_mask_granted
            for (j = 0; j < SLV_PORT_NUM; j = j + 1) begin: gen_mst_req_mask_granted_slv
                assign mst_req_mask_grt[i][j] = ({MLEN{req_lck_to_slv[i][j]}} & mst_req_mask_2d[i]);
            end
        end
    endgenerate

    generate
        for (i = 0; i < SLV_PORT_NUM; i = i + 1) begin: gen_slv_req_mask_granted
            for (j = 0; j < MLEN; j = j + 1) begin: gen_slv_req_mask_granted_bit
                for (k = 0; k < MST_PORT_NUM; k = k + 1) begin: gen_slv_req_mask_granted_mst
                    assign slv_req_mask_grt[i][j][k] = mst_req_mask_grt[k][i][j];
                end
            end
        end
    endgenerate

    generate
        for (i = 0; i < SLV_PORT_NUM; i = i + 1) begin: gen_slv_req_mask
            for (j = 0; j < MLEN; j = j + 1) begin: gen_slv_req_mask_bit
                assign slv_req_mask_2d[i][j] = |slv_req_mask_grt[i][j];
            end
        end
    endgenerate

    // Set slv_req_data.
    wire [DLEN-1:0]                 mst_req_data_grt [MST_PORT_NUM-1:0][SLV_PORT_NUM-1:0];
    wire [MST_PORT_NUM-1:0]         slv_req_data_grt [SLV_PORT_NUM-1:0][DLEN-1:0];

    generate
        for (i = 0; i < MST_PORT_NUM; i = i + 1) begin: gen_mst_req_data_granted
            for (j = 0; j < SLV_PORT_NUM; j = j + 1) begin: gen_mst_req_data_granted_slv
                assign mst_req_data_grt[i][j] = ({DLEN{req_lck_to_slv[i][j]}} & mst_req_data_2d[i]);
            end
        end
    endgenerate

    generate
        for (i = 0; i < SLV_PORT_NUM; i = i + 1) begin: gen_slv_req_data_granted
            for (j = 0; j < DLEN; j = j + 1) begin: gen_slv_req_data_granted_bit
                for (k = 0; k < MST_PORT_NUM; k = k + 1) begin: gen_slv_req_data_granted_mst
                    assign slv_req_data_grt[i][j][k] = mst_req_data_grt[k][i][j];
                end
            end
        end
    endgenerate

    generate
        for (i = 0; i < SLV_PORT_NUM; i = i + 1) begin: gen_slv_req_data
            for (j = 0; j < DLEN; j = j + 1) begin: gen_slv_req_data_bit
                assign slv_req_data_2d[i][j] = |slv_req_data_grt[i][j];
            end
        end
    endgenerate

    // Set slv_rsp_rdy.
    wire [SLV_PORT_NUM-1:0]         mst_rsp_rdy_grt [MST_PORT_NUM-1:0];
    wire [MST_PORT_NUM-1:0]         slv_rsp_rdy_grt [SLV_PORT_NUM-1:0];

    generate
        for (i = 0; i < MST_PORT_NUM; i = i + 1) begin: gen_mst_rsp_rdy_granted
            for (j = 0; j < SLV_PORT_NUM; j = j + 1) begin: gen_mst_rsp_rdy_granted_slv
                assign mst_rsp_rdy_grt[i][j] = slv_lck_to_mst[j][i] & mst_rsp_rdy[i];
            end
        end
    endgenerate

    generate
        for (i = 0; i < SLV_PORT_NUM; i = i + 1) begin: gen_slv_rsp_rdy_granted
            for (j = 0; j < MST_PORT_NUM; j = j + 1) begin: gen_slv_rsp_rdy_granted_mst
                assign slv_rsp_rdy_grt[i][j] = mst_rsp_rdy_grt[j][i];
            end
        end
    endgenerate

    generate
        for (i = 0; i < SLV_PORT_NUM; i = i + 1) begin: gen_slv_rsp_rdy
            assign slv_rsp_rdy[i] = |slv_rsp_rdy_grt[i];
        end
    endgenerate

    ///////////////////////
    // Master back pressure.
    wire [MST_PORT_NUM-1:0]         slv_req_rdy_grt [SLV_PORT_NUM-1:0];
    wire [SLV_PORT_NUM-1:0]         mst_req_rdy_grt [MST_PORT_NUM-1:0];

    generate
        for (i = 0; i < SLV_PORT_NUM; i = i + 1) begin: gen_slv_req_rdy_granted
            for (j = 0; j < MST_PORT_NUM; j = j + 1) begin: gen_slv_req_rdy_granted_mst
                assign slv_req_rdy_grt[i][j] = req_lck_to_slv[j][i] & slv_req_rdy[i];
            end
        end
    endgenerate

    generate
        for (i = 0; i < MST_PORT_NUM; i = i + 1) begin: gen_mst_req_rdy_granted
            for (j = 0; j < SLV_PORT_NUM; j = j + 1) begin: gen_mst_req_rdy_granted_slv
                assign mst_req_rdy_grt[i][j] = slv_req_rdy_grt[j][i];
            end
        end
    endgenerate

    generate
        for (i = 0; i < MST_PORT_NUM; i = i + 1) begin: gen_mst_req_rdy
            assign mst_req_rdy[i] = mst_acc_fault[i] | (|mst_req_rdy_grt[i]);
        end
    endgenerate

    // Master responses.
    generate
        for (i = 0; i < MST_PORT_NUM; i = i + 1) begin: gen_mst_fire
            assign mst_req_fire[i] = mst_req_vld[i] & mst_req_rdy[i];
            assign mst_rsp_fire[i] = mst_rsp_vld[i] & mst_rsp_rdy[i];
        end
    endgenerate
    
    generate
        for (i = 0; i < SLV_PORT_NUM; i = i + 1) begin: gen_slv_fire
            assign slv_req_fire[i] = slv_req_vld[i] & slv_req_rdy[i];
            assign slv_rsp_fire[i] = slv_rsp_vld[i] & slv_rsp_rdy[i];
        end
    endgenerate

    // Set mst_rsp_vld.
    wire [MST_PORT_NUM-1:0]         slv_rsp_vld_grt [SLV_PORT_NUM-1:0];
    wire [SLV_PORT_NUM-1:0]         mst_rsp_vld_grt [MST_PORT_NUM-1:0];

    generate
        for (i = 0; i < SLV_PORT_NUM; i = i + 1) begin: gen_slv_rsp_vld_granted
            for (j = 0; j < MST_PORT_NUM; j = j + 1) begin: gen_slv_rsp_vld_granted_mst
                assign slv_rsp_vld_grt[i][j] = mst_lck_to_slv[j][i] & slv_rsp_vld[i];
            end
        end
    endgenerate

    generate
        for (i = 0; i < MST_PORT_NUM; i = i + 1) begin: gen_mst_rsp_vld_granted
            for (j = 0; j < SLV_PORT_NUM; j = j + 1) begin: gen_mst_rsp_vld_granted_slv
                assign mst_rsp_vld_grt[i][j] = slv_rsp_vld_grt[j][i];
            end
        end
    endgenerate

    generate
        for (i = 0; i < MST_PORT_NUM; i = i + 1) begin: gen_mst_rsp_vld
            assign mst_rsp_vld[i] = mst_acc_fault_r[i] | (|mst_rsp_vld_grt[i]);
        end
    endgenerate

    // Set mst_rsp_excp.
    wire [1:0]                      slv_rsp_excp_grt [SLV_PORT_NUM-1:0][MST_PORT_NUM-1:0];
    wire [SLV_PORT_NUM-1:0]         mst_rsp_excp_grt [MST_PORT_NUM-1:0][1:0];

    generate
        for (i = 0; i < SLV_PORT_NUM; i = i + 1) begin: gen_slv_rsp_excp_granted
            for (j = 0; j < MST_PORT_NUM; j = j + 1) begin: gen_slv_rsp_excp_granted_mst
                assign slv_rsp_excp_grt[i][j] = ({2{mst_lck_to_slv[j][i]}} & slv_rsp_excp_2d[i]);
            end
        end
    endgenerate

    generate
        for (i = 0; i < MST_PORT_NUM; i = i + 1) begin: gen_mst_rsp_excp_granted
            for (j = 0; j < 2; j = j + 1) begin: gen_mst_rsp_excp_granted_bit
                for (k = 0; k < SLV_PORT_NUM; k = k + 1) begin: gen_mst_rsp_excp_granted_slv
                    assign mst_rsp_excp_grt[i][j][k] = slv_rsp_excp_grt[k][i][j];
                end
            end
        end
    endgenerate

    generate
        for (i = 0; i < MST_PORT_NUM; i = i + 1) begin: gen_mst_rsp_excp
            assign mst_rsp_excp_2d[i][0] = mst_acc_fault_r[i] ? 1'b1: |mst_rsp_excp_grt[i][0];
            assign mst_rsp_excp_2d[i][1] = mst_acc_fault_r[i] ? 1'b0: |mst_rsp_excp_grt[i][1];
        end
    endgenerate

    // Set mst_rsp_data.
    wire [DLEN-1:0]                 slv_rsp_data_grt [SLV_PORT_NUM-1:0][MST_PORT_NUM-1:0];
    wire [SLV_PORT_NUM-1:0]         mst_rsp_data_grt [MST_PORT_NUM-1:0][DLEN-1:0];

    generate
        for (i = 0; i < SLV_PORT_NUM; i = i + 1) begin: gen_slv_rsp_data_granted
            for (j = 0; j < MST_PORT_NUM; j = j + 1) begin: gen_slv_rsp_data_granted_mst
                assign slv_rsp_data_grt[i][j] = ({DLEN{mst_lck_to_slv[j][i]}} & slv_rsp_data_2d[i]);
            end
        end
    endgenerate

    generate
        for (i = 0; i < MST_PORT_NUM; i = i + 1) begin: gen_mst_rsp_data_granted
            for (j = 0; j < DLEN; j = j + 1) begin: gen_mst_rsp_data_granted_bit
                for (k = 0; k < SLV_PORT_NUM; k = k + 1) begin: gen_mst_rsp_data_granted_slv
                    assign mst_rsp_data_grt[i][j][k] = slv_rsp_data_grt[k][i][j];
                end
            end
        end
    endgenerate

    generate
        for (i = 0; i < MST_PORT_NUM; i = i + 1) begin: gen_mst_rsp_data
            for (j = 0; j < DLEN; j = j + 1) begin: gen_mst_rsp_data_bit
                assign mst_rsp_data_2d[i][j] = mst_acc_fault_r[i] ? 1'b0 : |mst_rsp_data_grt[i][j];
            end
        end
    endgenerate

    // Arbiters.
    generate
        if (MST_PORT_NUM == 1) begin: gen_arb_with_one_port
            for (i = 0; i < SLV_PORT_NUM; i = i + 1) begin: gen_arb_inst
                assign slv_arb_grant[i] = slv_arb_req[i];
            end
        end
        else begin: gen_arb_with_more_ports
            for (i = 0; i < SLV_PORT_NUM; i = i + 1) begin: gen_arb_inst
                uv_arb_rr
                #(
                    .WIDTH              ( MST_PORT_NUM      )
                )
                u_arb
                (
                    .clk                ( clk               ),
                    .rst_n              ( rst_n             ),
                    .req                ( slv_arb_req[i]    ),
                    .grant              ( slv_arb_grant[i]  )
                );
            end
        end
    endgenerate

endmodule

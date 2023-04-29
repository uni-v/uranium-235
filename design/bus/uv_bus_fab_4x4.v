//************************************************************
// See LICENSE for license details.
//
// Module: uv_bus_fab_4x4
//
// Designer: Owen
//
// Description:
//      Bus fabric with 4 master ports and 4 slave ports.
//************************************************************

`timescale 1ns / 1ps

module uv_bus_fab_4x4
#(
    parameter ALEN                  = 32,
    parameter DLEN                  = 32,
    parameter MLEN                  = DLEN / 8,
    parameter SLV0_BASE_LSB         = 29,
    parameter SLV0_BASE_ADDR        = 3'h0,
    parameter SLV1_BASE_LSB         = 29,
    parameter SLV1_BASE_ADDR        = 3'h1,
    parameter SLV2_BASE_LSB         = 29,
    parameter SLV2_BASE_ADDR        = 3'h2,
    parameter SLV3_BASE_LSB         = 29,
    parameter SLV3_BASE_ADDR        = 3'h3
)
(
    input                           clk,
    input                           rst_n,

    // Masters.
    input                           mst0_req_vld,
    output                          mst0_req_rdy,
    input                           mst0_req_read,
    input  [ALEN-1:0]               mst0_req_addr,
    input  [MLEN-1:0]               mst0_req_mask,
    input  [DLEN-1:0]               mst0_req_data,
    output                          mst0_rsp_vld,
    input                           mst0_rsp_rdy,
    output [1:0]                    mst0_rsp_excp,
    output [DLEN-1:0]               mst0_rsp_data,

    input                           mst1_req_vld,
    output                          mst1_req_rdy,
    input                           mst1_req_read,
    input  [ALEN-1:0]               mst1_req_addr,
    input  [MLEN-1:0]               mst1_req_mask,
    input  [DLEN-1:0]               mst1_req_data,
    output                          mst1_rsp_vld,
    input                           mst1_rsp_rdy,
    output [1:0]                    mst1_rsp_excp,
    output [DLEN-1:0]               mst1_rsp_data,

    input                           mst2_req_vld,
    output                          mst2_req_rdy,
    input                           mst2_req_read,
    input  [ALEN-1:0]               mst2_req_addr,
    input  [MLEN-1:0]               mst2_req_mask,
    input  [DLEN-1:0]               mst2_req_data,
    output                          mst2_rsp_vld,
    input                           mst2_rsp_rdy,
    output [1:0]                    mst2_rsp_excp,
    output [DLEN-1:0]               mst2_rsp_data,

    input                           mst3_req_vld,
    output                          mst3_req_rdy,
    input                           mst3_req_read,
    input  [ALEN-1:0]               mst3_req_addr,
    input  [MLEN-1:0]               mst3_req_mask,
    input  [DLEN-1:0]               mst3_req_data,
    output                          mst3_rsp_vld,
    input                           mst3_rsp_rdy,
    output [1:0]                    mst3_rsp_excp,
    output [DLEN-1:0]               mst3_rsp_data,

    // Slaves.
    output                          slv0_req_vld,
    input                           slv0_req_rdy,
    output                          slv0_req_read,
    output [ALEN-1:0]               slv0_req_addr,
    output [MLEN-1:0]               slv0_req_mask,
    output [DLEN-1:0]               slv0_req_data,
    input                           slv0_rsp_vld,
    output                          slv0_rsp_rdy,
    input  [1:0]                    slv0_rsp_excp,
    input  [DLEN-1:0]               slv0_rsp_data,

    output                          slv1_req_vld,
    input                           slv1_req_rdy,
    output                          slv1_req_read,
    output [ALEN-1:0]               slv1_req_addr,
    output [MLEN-1:0]               slv1_req_mask,
    output [DLEN-1:0]               slv1_req_data,
    input                           slv1_rsp_vld,
    output                          slv1_rsp_rdy,
    input  [1:0]                    slv1_rsp_excp,
    input  [DLEN-1:0]               slv1_rsp_data,

    output                          slv2_req_vld,
    input                           slv2_req_rdy,
    output                          slv2_req_read,
    output [ALEN-1:0]               slv2_req_addr,
    output [MLEN-1:0]               slv2_req_mask,
    output [DLEN-1:0]               slv2_req_data,
    input                           slv2_rsp_vld,
    output                          slv2_rsp_rdy,
    input  [1:0]                    slv2_rsp_excp,
    input  [DLEN-1:0]               slv2_rsp_data,

    output                          slv3_req_vld,
    input                           slv3_req_rdy,
    output                          slv3_req_read,
    output [ALEN-1:0]               slv3_req_addr,
    output [MLEN-1:0]               slv3_req_mask,
    output [DLEN-1:0]               slv3_req_data,
    input                           slv3_rsp_vld,
    output                          slv3_rsp_rdy,
    input  [1:0]                    slv3_rsp_excp,
    input  [DLEN-1:0]               slv3_rsp_data
);

    localparam UDLY = 1;
    genvar i, j, k;

    // Slave selections.
    wire [3:0]                      mst_addr_match  [3:0];  // mst_addr_match[mst][slv]
    wire [3:0]                      mst_sel_to_slv  [3:0];  // mst_sel_to_slv[mst][slv]
    wire [3:0]                      slv_sel_to_mst  [3:0];  // slv_sel_to_mst[slv][mst]

    // Arbiter ports.
    wire [3:0]                      slv_arb_req     [3:0];  // slv_arb_req[slv][mst]
    wire [3:0]                      slv_arb_grant   [3:0];  // slv_arb_grant[slv][mst]
    wire [3:0]                      mst_arb_grant   [3:0];  // mst_arb_grant[mst][slv]
    wire [3:0]                      slv_arb_grant_r [3:0];  // mst_arb_grant_r[slv][mst]
    reg  [3:0]                      mst_arb_grant_r [3:0];  // mst_arb_grant_r[mst][slv]

    // Port combinations.
    wire [3:0]                      mst_lck_to_slv  [3:0];  // mst_lck_to_slv[mst][slv]
    wire [3:0]                      slv_lck_to_mst  [3:0];  // slv_lck_to_mst[slv][mst]
    wire [3:0]                      mst_rsp_rdy;
    wire [3:0]                      slv_rsp_vld;

    // Master fires.
    wire [3:0]                      mst_req_fire;
    wire [3:0]                      mst_rsp_fire;

    // Match slave addresses.
    assign mst_addr_match[0][0]     = mst0_req_addr[ALEN-1:SLV0_BASE_LSB] == SLV0_BASE_ADDR;
    assign mst_addr_match[0][1]     = mst0_req_addr[ALEN-1:SLV1_BASE_LSB] == SLV1_BASE_ADDR;
    assign mst_addr_match[0][2]     = mst0_req_addr[ALEN-1:SLV2_BASE_LSB] == SLV2_BASE_ADDR;
    assign mst_addr_match[0][3]     = mst0_req_addr[ALEN-1:SLV3_BASE_LSB] == SLV3_BASE_ADDR;
    assign mst_addr_match[1][0]     = mst1_req_addr[ALEN-1:SLV0_BASE_LSB] == SLV0_BASE_ADDR;
    assign mst_addr_match[1][1]     = mst1_req_addr[ALEN-1:SLV1_BASE_LSB] == SLV1_BASE_ADDR;
    assign mst_addr_match[1][2]     = mst1_req_addr[ALEN-1:SLV2_BASE_LSB] == SLV2_BASE_ADDR;
    assign mst_addr_match[1][3]     = mst1_req_addr[ALEN-1:SLV3_BASE_LSB] == SLV3_BASE_ADDR;
    assign mst_addr_match[2][0]     = mst2_req_addr[ALEN-1:SLV0_BASE_LSB] == SLV0_BASE_ADDR;
    assign mst_addr_match[2][1]     = mst2_req_addr[ALEN-1:SLV1_BASE_LSB] == SLV1_BASE_ADDR;
    assign mst_addr_match[2][2]     = mst2_req_addr[ALEN-1:SLV2_BASE_LSB] == SLV2_BASE_ADDR;
    assign mst_addr_match[2][3]     = mst2_req_addr[ALEN-1:SLV3_BASE_LSB] == SLV3_BASE_ADDR;
    assign mst_addr_match[3][0]     = mst3_req_addr[ALEN-1:SLV0_BASE_LSB] == SLV0_BASE_ADDR;
    assign mst_addr_match[3][1]     = mst3_req_addr[ALEN-1:SLV1_BASE_LSB] == SLV1_BASE_ADDR;
    assign mst_addr_match[3][2]     = mst3_req_addr[ALEN-1:SLV2_BASE_LSB] == SLV2_BASE_ADDR;
    assign mst_addr_match[3][3]     = mst3_req_addr[ALEN-1:SLV3_BASE_LSB] == SLV3_BASE_ADDR;

    // Select slave for each master.
    assign mst_sel_to_slv[0][0]     = mst0_req_vld & mst_addr_match[0][0];
    assign mst_sel_to_slv[0][1]     = mst0_req_vld & mst_addr_match[0][1];
    assign mst_sel_to_slv[0][2]     = mst0_req_vld & mst_addr_match[0][2];
    assign mst_sel_to_slv[0][3]     = mst0_req_vld & mst_addr_match[0][3];
    assign mst_sel_to_slv[1][0]     = mst0_req_vld & mst_addr_match[1][0];
    assign mst_sel_to_slv[1][1]     = mst0_req_vld & mst_addr_match[1][1];
    assign mst_sel_to_slv[1][2]     = mst0_req_vld & mst_addr_match[1][2];
    assign mst_sel_to_slv[1][3]     = mst0_req_vld & mst_addr_match[1][3];
    assign mst_sel_to_slv[2][0]     = mst0_req_vld & mst_addr_match[2][0];
    assign mst_sel_to_slv[2][1]     = mst0_req_vld & mst_addr_match[2][1];
    assign mst_sel_to_slv[2][2]     = mst0_req_vld & mst_addr_match[2][2];
    assign mst_sel_to_slv[2][3]     = mst0_req_vld & mst_addr_match[2][3];
    assign mst_sel_to_slv[3][0]     = mst0_req_vld & mst_addr_match[3][0];
    assign mst_sel_to_slv[3][1]     = mst0_req_vld & mst_addr_match[3][1];
    assign mst_sel_to_slv[3][2]     = mst0_req_vld & mst_addr_match[3][2];
    assign mst_sel_to_slv[3][3]     = mst0_req_vld & mst_addr_match[3][3];

    // Transpose selection matrix.
    generate
        for (i = 0; i < 4; i = i + 1) begin: gen_trans_bus_sel_slv
            for (j = 0; j < 4; j = j + 1) begin: gen_trans_bus_sel_mst
                assign slv_sel_to_mst[i][j] = mst_sel_to_slv[j][i];
            end
        end
    endgenerate

    // Set arbiters requests.
    generate
        for (i = 0; i < 4; i = i + 1) begin: gen_arb_req
            assign slv_arb_req[i] = slv_sel_to_mst[i];
        end
    endgenerate

    // Transpose arbiter grants for masters.
    generate
        for (i = 0; i < 4; i = i + 1) begin: gen_trans_arb_grant_mst
            for (j = 0; j < 4; j = j + 1) begin: gen_trans_arb_grant_slv
                assign mst_arb_grant[i][j] = slv_arb_grant[j][i];
            end
        end
    endgenerate

    // Buffer grant status for masters.
    generate
        for (i = 0; i < 4; i = i + 1) begin: gen_arb_grant_buf
            always @(posedge clk or negedge rst_n) begin
                if (~rst_n) begin
                    mst_arb_grant_r[i] <= 4'b0;
                end
                else begin
                    if (|mst_arb_grant[i]) begin
                        mst_arb_grant_r[i] <= #UDLY mst_arb_grant[i];
                    end
                    else if (|(mst_arb_grant_r[i] & mst_rsp_fire[i])) begin
                        mst_arb_grant_r[i] <= #UDLY {4{1'b0}};
                    end
                end
            end
        end
    endgenerate

    // Transpose grant buffer for slaves.
    generate
        for (i = 0; i < 4; i = i + 1) begin: gen_trans_arb_grant_slv
            for (j = 0; j < 4; j = j + 1) begin: gen_trans_arb_grant_mst
                assign slv_arb_grant_r[i][j] = mst_arb_grant_r[j][i];
            end
        end
    endgenerate

    // Combine ports.
    assign mst_rsp_rdy      = {mst3_rsp_rdy, mst2_rsp_rdy, mst1_rsp_rdy, mst0_rsp_rdy};
    assign slv_rsp_vld      = {slv3_rsp_vld, slv2_rsp_vld, slv1_rsp_vld, slv0_rsp_vld};

    generate
        for (i = 0; i < 4; i = i + 1) begin: gen_mst_lck
            assign mst_lck_to_slv[i] = mst_arb_grant[i] | mst_arb_grant_r[i];
        end
    endgenerate

    generate
        for (i = 0; i < 4; i = i + 1) begin: gen_slv_lck
            assign slv_lck_to_mst[i] = slv_arb_grant[i] | slv_arb_grant_r[i];
        end
    endgenerate

    // Set slave requests.
    assign slv0_req_vld     = |slv_arb_grant[0];
    assign slv0_req_read    = (slv_arb_grant[0][0] & mst0_req_read)
                            | (slv_arb_grant[0][1] & mst1_req_read)
                            | (slv_arb_grant[0][2] & mst2_req_read)
                            | (slv_arb_grant[0][3] & mst3_req_read);
    assign slv0_req_addr    = ({ALEN{slv_arb_grant[0][0]}} & mst0_req_addr)
                            | ({ALEN{slv_arb_grant[0][1]}} & mst1_req_addr)
                            | ({ALEN{slv_arb_grant[0][2]}} & mst2_req_addr)
                            | ({ALEN{slv_arb_grant[0][3]}} & mst3_req_addr);
    assign slv0_req_mask    = ({MLEN{slv_arb_grant[0][0]}} & mst0_req_mask)
                            | ({MLEN{slv_arb_grant[0][1]}} & mst1_req_mask)
                            | ({MLEN{slv_arb_grant[0][2]}} & mst2_req_mask)
                            | ({MLEN{slv_arb_grant[0][3]}} & mst3_req_mask);
    assign slv0_req_data    = ({DLEN{slv_arb_grant[0][0]}} & mst0_req_data)
                            | ({DLEN{slv_arb_grant[0][1]}} & mst1_req_data)
                            | ({DLEN{slv_arb_grant[0][2]}} & mst2_req_data)
                            | ({DLEN{slv_arb_grant[0][3]}} & mst3_req_data);
    assign slv0_rsp_rdy     = |(slv_lck_to_mst[0] & mst_rsp_rdy);

    assign slv1_req_vld     = |slv_arb_grant[1];
    assign slv1_req_read    = (slv_arb_grant[1][0] & mst0_req_read)
                            | (slv_arb_grant[1][1] & mst1_req_read)
                            | (slv_arb_grant[1][2] & mst2_req_read)
                            | (slv_arb_grant[1][3] & mst3_req_read);
    assign slv1_req_addr    = ({ALEN{slv_arb_grant[1][0]}} & mst0_req_addr)
                            | ({ALEN{slv_arb_grant[1][1]}} & mst1_req_addr)
                            | ({ALEN{slv_arb_grant[1][2]}} & mst2_req_addr)
                            | ({ALEN{slv_arb_grant[1][3]}} & mst3_req_addr);
    assign slv1_req_mask    = ({MLEN{slv_arb_grant[1][0]}} & mst0_req_mask)
                            | ({MLEN{slv_arb_grant[1][1]}} & mst1_req_mask)
                            | ({MLEN{slv_arb_grant[1][2]}} & mst2_req_mask)
                            | ({MLEN{slv_arb_grant[1][3]}} & mst3_req_mask);
    assign slv1_req_data    = ({DLEN{slv_arb_grant[1][0]}} & mst0_req_data)
                            | ({DLEN{slv_arb_grant[1][1]}} & mst1_req_data)
                            | ({DLEN{slv_arb_grant[1][2]}} & mst2_req_data)
                            | ({DLEN{slv_arb_grant[1][3]}} & mst3_req_data);
    assign slv1_rsp_rdy     = |(slv_lck_to_mst[1] & mst_rsp_rdy);

    assign slv2_req_vld     = |slv_arb_grant[2];
    assign slv2_req_read    = (slv_arb_grant[2][0] & mst0_req_read)
                            | (slv_arb_grant[2][1] & mst1_req_read)
                            | (slv_arb_grant[2][2] & mst2_req_read)
                            | (slv_arb_grant[2][3] & mst3_req_read);
    assign slv2_req_addr    = ({ALEN{slv_arb_grant[2][0]}} & mst0_req_addr)
                            | ({ALEN{slv_arb_grant[2][1]}} & mst1_req_addr)
                            | ({ALEN{slv_arb_grant[2][2]}} & mst2_req_addr)
                            | ({ALEN{slv_arb_grant[2][3]}} & mst3_req_addr);
    assign slv2_req_mask    = ({MLEN{slv_arb_grant[2][0]}} & mst0_req_mask)
                            | ({MLEN{slv_arb_grant[2][1]}} & mst1_req_mask)
                            | ({MLEN{slv_arb_grant[2][2]}} & mst2_req_mask)
                            | ({MLEN{slv_arb_grant[2][3]}} & mst3_req_mask);
    assign slv2_req_data    = ({DLEN{slv_arb_grant[2][0]}} & mst0_req_data)
                            | ({DLEN{slv_arb_grant[2][1]}} & mst1_req_data)
                            | ({DLEN{slv_arb_grant[2][2]}} & mst2_req_data)
                            | ({DLEN{slv_arb_grant[2][3]}} & mst3_req_data);
    assign slv2_rsp_rdy     = |(slv_lck_to_mst[2] & mst_rsp_rdy);

    assign slv3_req_vld     = |slv_arb_grant[3];
    assign slv3_req_read    = (slv_arb_grant[3][0] & mst0_req_read)
                            | (slv_arb_grant[3][1] & mst1_req_read)
                            | (slv_arb_grant[3][2] & mst2_req_read)
                            | (slv_arb_grant[3][3] & mst3_req_read);
    assign slv3_req_addr    = ({ALEN{slv_arb_grant[3][0]}} & mst0_req_addr)
                            | ({ALEN{slv_arb_grant[3][1]}} & mst1_req_addr)
                            | ({ALEN{slv_arb_grant[3][2]}} & mst2_req_addr)
                            | ({ALEN{slv_arb_grant[3][3]}} & mst3_req_addr);
    assign slv3_req_mask    = ({MLEN{slv_arb_grant[3][0]}} & mst0_req_mask)
                            | ({MLEN{slv_arb_grant[3][1]}} & mst1_req_mask)
                            | ({MLEN{slv_arb_grant[3][2]}} & mst2_req_mask)
                            | ({MLEN{slv_arb_grant[3][3]}} & mst3_req_mask);
    assign slv3_req_data    = ({DLEN{slv_arb_grant[3][0]}} & mst0_req_data)
                            | ({DLEN{slv_arb_grant[3][1]}} & mst1_req_data)
                            | ({DLEN{slv_arb_grant[3][2]}} & mst2_req_data)
                            | ({DLEN{slv_arb_grant[3][3]}} & mst3_req_data);
    assign slv3_rsp_rdy     = |(slv_lck_to_mst[3] & mst_rsp_rdy);

    // Master back pressure.
    assign mst0_req_rdy     = |mst_arb_grant[0];
    assign mst1_req_rdy     = |mst_arb_grant[1];
    assign mst2_req_rdy     = |mst_arb_grant[2];
    assign mst3_req_rdy     = |mst_arb_grant[3];

    // Master responses.
    assign mst_req_fire[0]  = mst0_req_vld & mst0_req_rdy;
    assign mst_req_fire[1]  = mst1_req_vld & mst1_req_rdy;
    assign mst_req_fire[2]  = mst2_req_vld & mst2_req_rdy;
    assign mst_req_fire[3]  = mst3_req_vld & mst3_req_rdy;
    assign mst_rsp_fire[0]  = mst0_rsp_vld & mst0_rsp_rdy;
    assign mst_rsp_fire[1]  = mst1_rsp_vld & mst1_rsp_rdy;
    assign mst_rsp_fire[2]  = mst2_rsp_vld & mst2_rsp_rdy;
    assign mst_rsp_fire[3]  = mst3_rsp_vld & mst3_rsp_rdy;

    assign mst0_rsp_vld     = |(mst_lck_to_slv[0] & slv_rsp_vld);
    assign mst0_rsp_excp    = ({2{mst_lck_to_slv[0][0]}} & slv0_rsp_excp)
                            | ({2{mst_lck_to_slv[0][1]}} & slv1_rsp_excp)
                            | ({2{mst_lck_to_slv[0][2]}} & slv2_rsp_excp)
                            | ({2{mst_lck_to_slv[0][3]}} & slv3_rsp_excp);
    assign mst0_rsp_data    = ({DLEN{mst_lck_to_slv[0][0]}} & slv0_rsp_data)
                            | ({DLEN{mst_lck_to_slv[0][1]}} & slv1_rsp_data)
                            | ({DLEN{mst_lck_to_slv[0][2]}} & slv2_rsp_data)
                            | ({DLEN{mst_lck_to_slv[0][3]}} & slv3_rsp_data);

    assign mst1_rsp_vld     = |(mst_lck_to_slv[1] & slv_rsp_vld);
    assign mst1_rsp_excp    = ({2{mst_lck_to_slv[1][0]}} & slv0_rsp_excp)
                            | ({2{mst_lck_to_slv[1][1]}} & slv1_rsp_excp)
                            | ({2{mst_lck_to_slv[1][2]}} & slv2_rsp_excp)
                            | ({2{mst_lck_to_slv[1][3]}} & slv3_rsp_excp);
    assign mst1_rsp_data    = ({DLEN{mst_lck_to_slv[1][0]}} & slv0_rsp_data)
                            | ({DLEN{mst_lck_to_slv[1][1]}} & slv1_rsp_data)
                            | ({DLEN{mst_lck_to_slv[1][2]}} & slv2_rsp_data)
                            | ({DLEN{mst_lck_to_slv[1][3]}} & slv3_rsp_data);

    assign mst2_rsp_vld     = |(mst_lck_to_slv[2] & slv_rsp_vld);
    assign mst2_rsp_excp    = ({2{mst_lck_to_slv[2][0]}} & slv0_rsp_excp)
                            | ({2{mst_lck_to_slv[2][1]}} & slv1_rsp_excp)
                            | ({2{mst_lck_to_slv[2][2]}} & slv2_rsp_excp)
                            | ({2{mst_lck_to_slv[2][3]}} & slv3_rsp_excp);
    assign mst2_rsp_data    = ({DLEN{mst_lck_to_slv[2][0]}} & slv0_rsp_data)
                            | ({DLEN{mst_lck_to_slv[2][1]}} & slv1_rsp_data)
                            | ({DLEN{mst_lck_to_slv[2][2]}} & slv2_rsp_data)
                            | ({DLEN{mst_lck_to_slv[2][3]}} & slv3_rsp_data);

    assign mst3_rsp_vld     = |(mst_lck_to_slv[3] & slv_rsp_vld);
    assign mst3_rsp_excp    = ({2{mst_lck_to_slv[3][0]}} & slv0_rsp_excp)
                            | ({2{mst_lck_to_slv[3][1]}} & slv1_rsp_excp)
                            | ({2{mst_lck_to_slv[3][2]}} & slv2_rsp_excp)
                            | ({2{mst_lck_to_slv[3][3]}} & slv3_rsp_excp);
    assign mst3_rsp_data    = ({DLEN{mst_lck_to_slv[3][0]}} & slv0_rsp_data)
                            | ({DLEN{mst_lck_to_slv[3][1]}} & slv1_rsp_data)
                            | ({DLEN{mst_lck_to_slv[3][2]}} & slv2_rsp_data)
                            | ({DLEN{mst_lck_to_slv[3][3]}} & slv3_rsp_data);

    // Arbiters.
    generate
        for (i = 0; i < 4; i = i + 1) begin: gen_arb_inst
            uv_arb_rr
            #(
                .WIDTH              ( 4                 )
            )
            u_arb
            (
                .clk                ( clk               ),
                .rst_n              ( rst_n             ),
                .req                ( slv_arb_req[i]    ),
                .grant              ( slv_arb_grant[i]  )
            );
        end
    endgenerate

endmodule

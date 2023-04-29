//************************************************************
// See LICENSE for license details.
//
// Module: uv_div
//
// Designer: Owen
//
// Description:
//      Multi-cycle Divider.
//************************************************************

`timescale 1ns / 1ps

module uv_div
#(
    parameter DIV_DW        = 32
)
(
    input                   clk,
    input                   rst_n,
    
    output                  req_rdy,
    input                   req_vld,
    input                   req_sgn,
    input                   req_rem,

    input  [DIV_DW-1:0]     req_opa,
    input  [DIV_DW-1:0]     req_opb,

    output                  rsp_vld,
    output [DIV_DW-1:0]     rsp_res
);

    localparam UDLY         = 1;
    localparam DVS_WIDTH    = DIV_DW + 1;           // Divisor width.
    localparam DVD_WIDTH    = DIV_DW + 1;           // Dividend width.
    localparam CNT_WIDTH    = $clog2(DVD_WIDTH);    // Counter width.
    localparam CNT_MAX      = DVD_WIDTH - 1;

    wire                    opb_zero;
    wire                    dvs_zero;
    wire                    div_start;

    wire                    opa_sgn;
    wire                    opb_sgn;
    wire [DVD_WIDTH-1:0]    ext_opa;
    wire [DVS_WIDTH-1:0]    ext_opb;

    wire [DVD_WIDTH-1:0]    opa_neg;
    wire [DVS_WIDTH-1:0]    opb_neg;
    wire [DVD_WIDTH-1:0]    ext_dvd;
    wire [DVS_WIDTH-1:0]    ext_dvs;

    wire [DVD_WIDTH-1:0]    quo_neg;
    wire [DVS_WIDTH-1:0]    quo_res;

    wire [DVS_WIDTH-1:0]    div_rem;
    wire [DVD_WIDTH-1:0]    rem_neg;
    wire [DVS_WIDTH-1:0]    rem_res;

    wire                    div_end;
    wire                    rem_add_sel;
    wire [DVS_WIDTH:0]      div_rem_add;
    wire [DVS_WIDTH:0]      div_rem_sub;
    wire [DVS_WIDTH:0]      div_rem_nxt;

    reg  [DVD_WIDTH-1:0]    div_quo_r;
    reg  [DVS_WIDTH-1:0]    div_rem_r;
    reg  [DVS_WIDTH-1:0]    div_dvs_r;
    reg  [CNT_WIDTH-1:0]    div_cnt_r;
    reg                     rem_sgn_r;
    reg                     res_sgn_r;
    reg                     opa_sgn_r;
    reg                     req_rem_r;
    reg                     busy_r;
    reg                     busy_p;

    // Back pressure.
    assign req_rdy          = ~busy_r;

    // Start division.
    assign opb_zero         = ~(|req_opb);
    assign dvs_zero         = req_vld & opb_zero;
    assign div_start        = req_vld & (~opb_zero);

    // Extend operands according to sign.
    assign opa_sgn          = req_sgn & req_opa[DIV_DW-1];
    assign opb_sgn          = req_sgn & req_opb[DIV_DW-1];
    assign ext_opa          = {{(DVD_WIDTH-DIV_DW){opa_sgn}}, req_opa};
    assign ext_opb          = {{(DVS_WIDTH-DIV_DW){opb_sgn}}, req_opb};

    assign opa_neg          = (~ext_opa) + 1'b1;
    assign opb_neg          = (~ext_opb) + 1'b1;
    assign ext_dvd          = opa_sgn ? opa_neg : ext_opa;
    assign ext_dvs          = opb_sgn ? opb_neg : ext_opb;

    // Calculate the next remainder.
    assign rem_add_sel      = rem_sgn_r ^ div_dvs_r[DVS_WIDTH-1];
    assign div_rem_add      = {div_rem_r, div_quo_r[DVD_WIDTH-1]} + {div_dvs_r[DVS_WIDTH-1], div_dvs_r};
    assign div_rem_sub      = {div_rem_r, div_quo_r[DVD_WIDTH-1]} - {div_dvs_r[DVS_WIDTH-1], div_dvs_r};
    assign div_rem_nxt      = rem_add_sel ? div_rem_add : div_rem_sub;

    // Check end status.
    assign div_end          = div_cnt_r == CNT_MAX[CNT_WIDTH-1:0];

    // Get the final quotient & remainder.
    assign quo_neg          = (~div_quo_r) + 1'b1;
    assign quo_res          = res_sgn_r ? quo_neg[DVS_WIDTH-1:0] : div_quo_r[DVS_WIDTH-1:0];

    assign div_rem          = rem_sgn_r ? div_rem_r + div_dvs_r : div_rem_r;
    assign rem_neg          = (~div_rem) + 1'b1;
    assign rem_res          = (opa_sgn_r ^ div_rem[DVS_WIDTH-1]) ? rem_neg : div_rem;

    // Output result.
    assign rsp_vld          = dvs_zero | (~busy_r & busy_p);
    assign rsp_res          = (dvs_zero & (~req_rem)) ? {DIV_DW{1'b1}}
                            : (dvs_zero & req_rem) ? req_opa
                            : req_rem_r ? rem_res[DIV_DW-1:0] : quo_res[DIV_DW-1:0];

    // Update busy status.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            busy_r <= 1'b0;
        end
        else begin
            if (busy_r & div_end) begin
                busy_r <= #UDLY 1'b0;
            end
            else if (div_start) begin
                busy_r <= #UDLY 1'b1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            busy_p <= 1'b0;
        end
        else begin
            busy_p <= #UDLY busy_r;
        end
    end

    // Update counter.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            div_cnt_r <= {CNT_WIDTH{1'b0}};
        end
        else begin
            if (busy_r) begin
                div_cnt_r <= #UDLY div_cnt_r + 1'b1;
            end
            else if (div_start) begin
                div_cnt_r <= #UDLY {CNT_WIDTH{1'b0}};
            end
        end
    end

    // Update quotient.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            div_quo_r <= {DVD_WIDTH{1'b0}};
        end
        else begin
            if (busy_r) begin
                div_quo_r <= #UDLY {div_quo_r[DVD_WIDTH-2:0], ~div_rem_nxt[DVS_WIDTH]};
            end
            else if (div_start) begin
                div_quo_r <= #UDLY ext_dvd;
            end
        end
    end

    // Update remainder.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            div_rem_r <= {DVS_WIDTH{1'b0}};
        end
        else begin
            if (busy_r) begin
                div_rem_r <= #UDLY div_rem_nxt[DVS_WIDTH-1:0];
            end
            else if (div_start) begin
                div_rem_r <= #UDLY {DVS_WIDTH{1'b0}};
            end
        end
    end

    // Update remainder sign.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rem_sgn_r <= {CNT_WIDTH{1'b0}};
        end
        else begin
            if (busy_r) begin
                rem_sgn_r <= #UDLY div_rem_nxt[DVS_WIDTH];
            end
            else if (div_start) begin
                rem_sgn_r <= #UDLY ext_dvd[DVD_WIDTH-1];
            end
        end
    end

    // Buffer request info.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            res_sgn_r <= 1'b0;
            opa_sgn_r <= 1'b0;
            req_rem_r <= 1'b0;
            div_dvs_r <= {DVS_WIDTH{1'b0}};
        end
        else begin
            if (div_start) begin
                res_sgn_r <= #UDLY opa_sgn ^ opb_sgn;
                opa_sgn_r <= #UDLY opa_sgn;
                req_rem_r <= #UDLY req_rem;
                div_dvs_r <= #UDLY ext_dvs;
            end
        end
    end

endmodule

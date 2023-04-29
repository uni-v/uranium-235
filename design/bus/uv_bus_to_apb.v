//************************************************************
// See LICENSE for license details.
//
// Module: uv_bus_to_apb
//
// Designer: Owen
//
// Description:
//      Transform interface from bus to APB.
//************************************************************

`timescale 1ns / 1ps

module uv_bus_to_apb
#(
    parameter ALEN                  = 12,
    parameter DLEN                  = 32,
    parameter MLEN                  = DLEN / 8,
    parameter PIPE                  = 1'b1
)
(
    input                           clk,
    input                           rst_n,

    // Bus ports.
    input                           bus_req_vld,
    output                          bus_req_rdy,
    input                           bus_req_read,
    input  [ALEN-1:0]               bus_req_addr,
    input  [MLEN-1:0]               bus_req_mask,
    input  [DLEN-1:0]               bus_req_data,

    output                          bus_rsp_vld,
    input                           bus_rsp_rdy,
    output [1:0]                    bus_rsp_excp,
    output [DLEN-1:0]               bus_rsp_data,

    // APB ports.
    output                          apb_psel,
    output                          apb_penable,
    output [2:0]                    apb_pprot,
    output [ALEN-1:0]               apb_paddr,
    output [MLEN-1:0]               apb_pstrb,
    output                          apb_pwrite,
    output [DLEN-1:0]               apb_pwdata,
    input  [DLEN-1:0]               apb_prdata,
    input                           apb_pready,
    input                           apb_pslverr
);

    localparam UDLY = 1;
    
    reg                             req_rdy_r;
    reg                             req_vld_r;
    reg                             req_read_r;
    reg  [ALEN-1:0]                 req_addr_r;
    reg  [MLEN-1:0]                 req_mask_r;
    reg  [DLEN-1:0]                 req_data_r;

    reg                             rsp_vld_r;
    reg                             rsp_excp_r;
    reg  [DLEN-1:0]                 rsp_data_r;

    reg                             apb_penable_r;
    reg  [ALEN-1:0]                 apb_paddr_r;
    reg  [MLEN-1:0]                 apb_pstrb_r;
    reg                             apb_pwrite_r;
    reg  [DLEN-1:0]                 apb_pwdata_r;

    wire                            apb_busy;
    wire                            apb_okay;

    assign apb_busy                 = req_vld_r | apb_penable_r;
    assign apb_okay                 = apb_penable & apb_pready;

    // Bus output.
    assign bus_req_rdy              = (~bus_req_vld | req_vld_r) & req_rdy_r;
    assign bus_rsp_vld              = apb_okay | rsp_vld_r;
    assign bus_rsp_excp             = apb_okay ? {1'b0, apb_pslverr} : {1'b0, rsp_excp_r};
    assign bus_rsp_data             = apb_okay ? apb_prdata : rsp_data_r;

    // APB output.
    assign apb_psel                 = apb_busy;
    assign apb_penable              = apb_penable_r;
    assign apb_pprot                = 3'b0;
    assign apb_paddr                = req_vld_r ? req_addr_r  : apb_paddr_r;
    assign apb_pstrb                = req_vld_r ? req_mask_r  : apb_pstrb_r;
    assign apb_pwrite               = req_vld_r ? ~req_read_r : apb_pwrite_r;
    assign apb_pwdata               = req_vld_r ? req_data_r  : apb_pwdata_r;

    // Bus back pressure.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            req_rdy_r <= 1'b1;
        end
        else begin
            if (apb_okay) begin
                req_rdy_r <= #UDLY 1'b1;
            end
            else if (req_vld_r) begin
                req_rdy_r <= #UDLY 1'b0;
            end
        end
    end

    // Buffer bus output.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rsp_vld_r  <= 1'b0;
            rsp_excp_r <= 1'b0;
        end
        else begin
            if (apb_okay & (~bus_rsp_rdy)) begin
                rsp_vld_r  <= #UDLY 1'b1;
                rsp_excp_r <= #UDLY apb_pslverr;
            end
            else if (bus_rsp_vld & bus_rsp_rdy) begin
                rsp_vld_r  <= #UDLY 1'b0;
                rsp_excp_r <= #UDLY 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rsp_data_r <= {DLEN{1'b0}};
        end
        else begin
            if (apb_okay) begin
                rsp_data_r <= #UDLY apb_prdata;
            end
        end
    end

    // Buffer bus input.
    generate
        if (PIPE) begin: gen_bus_req_pipe
            always @(posedge clk or negedge rst_n) begin
                if (~rst_n) begin
                    req_vld_r  <= 1'b0;
                    req_read_r <= 1'b0;
                    req_addr_r <= {ALEN{1'b0}};
                    req_mask_r <= {MLEN{1'b0}};
                    req_data_r <= {DLEN{1'b0}};
                end
                else begin
                    req_vld_r  <= #UDLY bus_req_vld;
                    req_read_r <= #UDLY bus_req_read;
                    req_addr_r <= #UDLY bus_req_addr;
                    req_mask_r <= #UDLY bus_req_mask;
                    req_data_r <= #UDLY bus_req_data;
                end
            end
        end
        else begin: gen_bus_req_imm
            always @(*) begin
                req_vld_r  = bus_req_vld;
                req_read_r = bus_req_read;
                req_addr_r = bus_req_addr;
                req_mask_r = bus_req_mask;
                req_data_r = bus_req_data;
            end
        end
    endgenerate

    // Buffer APB output.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            apb_penable_r <= 1'b0;
            apb_paddr_r   <= {ALEN{1'b0}};
            apb_pstrb_r   <= {MLEN{1'b0}};
            apb_pwrite_r  <= 1'b0;
            apb_pwdata_r  <= {DLEN{1'b0}};
        end
        else begin
            if (apb_okay) begin
                apb_penable_r <= #UDLY 1'b0;
            end
            else if (req_vld_r) begin
                apb_penable_r <= #UDLY 1'b1;
                apb_paddr_r   <= #UDLY req_addr_r;
                apb_pstrb_r   <= #UDLY req_mask_r;
                apb_pwrite_r  <= #UDLY ~req_read_r;
                apb_pwdata_r  <= #UDLY req_data_r;
            end
        end
    end

endmodule

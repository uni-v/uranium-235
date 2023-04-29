//************************************************************
// See LICENSE for license details.
//
// Module: uv_bus_to_ahb
//
// Designer: Owen
//
// Description:
//      Transform interface from bus to AHB.
//************************************************************

`timescale 1ns / 1ps

module uv_bus_to_ahb
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

    // AHB ports.
    output                          ahb_hsel,
    output [ALEN-1:0]               ahb_haddr,
    output [2:0]                    ahb_hburst,
    output [1:0]                    ahb_htrans,
    output [2:0]                    ahb_hsize,
    output [3:0]                    ahb_hprot,
    output                          ahb_hmastlock,
    output                          ahb_hwrite,
    output [DLEN-1:0]               ahb_hwdata,
    input  [DLEN-1:0]               ahb_hrdata,
    input                           ahb_hreadyout,
    input                           ahb_hresp
);

    localparam UDLY = 1;
    
    reg                             req_vld_r;
    reg                             req_read_r;
    reg  [ALEN-1:0]                 req_addr_r;
    reg  [MLEN-1:0]                 req_mask_r;
    reg  [DLEN-1:0]                 req_data_r;

    reg                             rsp_vld_r;
    reg                             rsp_excp_r;
    reg  [DLEN-1:0]                 rsp_data_r;

    reg  [2:0]                      ahb_hsize_t;
    reg  [DLEN-1:0]                 ahb_hwdata_r;
    reg                             ahb_busy_r;
    wire                            ahb_okay;

    assign ahb_okay                 = ahb_busy_r & ahb_hreadyout;

    // Bus output.
    assign bus_req_rdy              = ~(ahb_busy_r & (~ahb_hreadyout));
    assign bus_rsp_vld              = ahb_okay | rsp_vld_r;
    assign bus_rsp_excp             = ahb_okay ? {1'b0, ahb_hresp} : {1'b0, rsp_excp_r};
    assign bus_rsp_data             = ahb_okay ? ahb_hrdata : rsp_data_r;

    // AHB output.
    assign ahb_hsel                 = req_vld_r;
    assign ahb_haddr                = req_addr_r;
    assign ahb_hburst               = 3'b000;
    assign ahb_htrans               = req_vld_r ? 2'b10 : 2'b00;
    assign ahb_hsize                = ahb_hsize_t;
    assign ahb_hprot                = 4'b0011;
    assign ahb_hmastlock            = 1'b0;
    assign ahb_hwrite               = ~req_read_r;
    assign ahb_hwdata               = ahb_hwdata_r;

    // Buffer bus output.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rsp_vld_r  <= 1'b0;
            rsp_excp_r <= 1'b0;
        end
        else begin
            if (ahb_okay & (~bus_rsp_rdy)) begin
                rsp_vld_r  <= #ULDY 1'b1;
                rsp_excp_r <= #ULDY ahb_hresp;
            end
            else if (bus_rsp_vld & bus_rsp_rdy) begin
                rsp_vld_r  <= #ULDY 1'b0;
                rsp_excp_r <= #ULDY 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rsp_data_r <= {DLEN{1'b0}};
        end
        else begin
            if (ahb_okay) begin
                rsp_data_r <= #ULDY ahb_hrdata;
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

    // Mask to size.
    generate
        if (DLEN == 32) begin: gen_hsize_32b
            always @(*) begin
                case (req_mask_r[3:0])
                    4'b0001: ahb_hsize_t = 3'd0;
                    4'b0011: ahb_hsize_t = 3'd1;
                    default: ahb_hsize_t = 3'd2;
                endcase
            end
        end
        else begin: gen_hsize_64b
            always @(*) begin
                case (req_mask_r[7:0])
                    8'b00000001: ahb_hsize_t = 3'd0;
                    8'b00000011: ahb_hsize_t = 3'd1;
                    8'b00001111: ahb_hsize_t = 3'd2;
                    default    : ahb_hsize_t = 3'd3;
                endcase
            end
        end
    endgenerate

    // Delay AHB data output.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            ahb_hwdata_r <= {DLEN{1'b0}};
        end
        else begin
            if (req_vld_r) begin
                ahb_hwdata_r <= #ULDY req_data_r;
            end
        end
    end

    // Buffer AHB busy status.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            ahb_busy_r <= 1'b0;
        end
        else begin
            if (ahb_htrans != 2'b0) begin
                ahb_busy_r <= #UDLY 1'b1;
            end
            else if (ahb_okay) begin
                ahb_busy_r <= #ULDY 1'b0;
            end
        end
    end

endmodule

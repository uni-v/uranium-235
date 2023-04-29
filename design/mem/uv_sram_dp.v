//************************************************************
// See LICENSE for license details.
//
// Module: uv_sram_dp
//
// Designer: Owen
//
// Description:
//      Simulation model of double-port SRAM.
//************************************************************

`timescale 1ns / 1ps

module uv_sram_dp
#(
    parameter RAM_AW  = 8,
    parameter RAM_DP  = 2**RAM_AW,
    parameter RAM_DW  = 32,
    parameter RAM_MW  = RAM_DW/8,
    parameter RAM_DLY = 0
)
(
    input                   clk,
    
    input                   cea,
    input                   wea,
    input  [RAM_AW-1:0]     aa,
    input  [RAM_DW-1:0]     da,
    input  [RAM_MW-1:0]     ma,
    output [RAM_DW-1:0]     qa,
    
    input                   ceb,
    input                   web,
    input  [RAM_AW-1:0]     ab,
    input  [RAM_DW-1:0]     db,
    input  [RAM_MW-1:0]     mb,
    output [RAM_DW-1:0]     qb
);

    localparam UDLY         = 1;
    localparam BYTE_NUM     = RAM_DW/8;
    localparam DLY_CW       = RAM_DLY > 0 ? $clog2(RAM_DLY) : 1;
    
    genvar i;
    
    reg  [RAM_DW-1:0]       ram [RAM_DP-1:0];
    reg  [RAM_DW-1:0]       qa_r;
    reg  [RAM_DW-1:0]       qb_r;
    wire                    wa;
    wire                    wb;
    wire                    ra;
    wire                    rb;
    wire [BYTE_NUM-1:0]     wma;
    wire [BYTE_NUM-1:0]     wmb;

    assign wa = cea & wea;
    assign wb = ceb & web;
    assign ra = cea & (~wea);
    assign rb = ceb & (~web);
    
    generate
        for (i = 0; i < BYTE_NUM; i = i + 1) begin: gen_wm
            if (i < RAM_MW) begin: gen_low_wm
                assign wma[i] = wa & ma[i];
                assign wmb[i] = wb & mb[i];
            end
            else begin: gen_high_wm
                assign wma[i] = wa;
                assign wmb[i] = wb;
            end
        end
    endgenerate
    
    generate
        for (i = 0; i < BYTE_NUM; i = i + 1) begin: gen_ram_wr
            if (RAM_DLY == 0) begin: gen_ram_wr_without_dly
                always @(posedge clk) begin
                    if (wma[i]) begin
                        ram[aa][8*(i+1)-1:8*i] <= #UDLY da[8*(i+1)-1:8*i];
                    end
                    if (wmb[i]) begin
                        ram[ab][8*(i+1)-1:8*i] <= #UDLY db[8*(i+1)-1:8*i];
                    end
                end
            end
            else begin: gen_ram_wr_with_dly
                always @(posedge clk) begin
                    if (wma[i] | wmb[i]) begin
                        repeat(RAM_DLY) @(posedge clk);
                    end
                    if (wma[i]) begin
                        ram[aa][8*(i+1)-1:8*i] <= #UDLY da[8*(i+1)-1:8*i];
                    end
                    if (wmb[i]) begin
                        ram[ab][8*(i+1)-1:8*i] <= #UDLY db[8*(i+1)-1:8*i];
                    end
                end
            end
        end
    endgenerate
    
    generate
        if (RAM_DLY == 0) begin: gen_qa_without_dly
            always @(posedge clk) begin
                if (ra) begin
                    qa_r <= #UDLY ram[aa];
                end
            end
        end
        else begin: gen_qa_with_dly
            always @(posedge clk) begin
                if (ra) begin
                    repeat(RAM_DLY) @(posedge clk);
                    qa_r <= #UDLY ram[aa];
                end
            end
        end
    endgenerate
    
    generate
        if (RAM_DLY == 0) begin: gen_qa_without_dly
            always @(posedge clk) begin
                if (rb) begin
                    qb_r <= #UDLY ram[ab];
                end
            end
        end
        else begin: gen_qa_with_dly
            always @(posedge clk) begin
                if (rb) begin
                    repeat(RAM_DLY) @(posedge clk);
                    qb_r <= #UDLY ram[ab];
                end
            end
        end
    endgenerate
    
    assign qa = qa_r;
    assign qb = qb_r;

endmodule

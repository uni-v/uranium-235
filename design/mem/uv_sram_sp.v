//************************************************************
// See LICENSE for license details.
//
// Module: uv_sram_sp
//
// Designer: Owen
//
// Description:
//      Simulation model of single-port SRAM.
//************************************************************

`timescale 1ns / 1ps

module uv_sram_sp
#(
    parameter RAM_AW  = 8,
    parameter RAM_DP  = 2**RAM_AW,
    parameter RAM_DW  = 32,
    parameter RAM_MW  = RAM_DW/8,
    parameter RAM_ME  = 1,
    parameter RAM_DLY = 0   // Only for simulation if RAM_DLY > 0.
)
(
    input                   clk,
    input                   ce,
    input                   we,
    input  [RAM_AW-1:0]     a,
    input  [RAM_DW-1:0]     d,
    input  [RAM_MW-1:0]     m,
    output [RAM_DW-1:0]     q
);

    localparam UDLY         = 1;
    localparam BYTE_NUM     = RAM_DW / 8;
    localparam DLY_CW       = RAM_DLY > 0 ? $clog2(RAM_DLY) : 1;
    
    genvar i;
    
    reg  [RAM_DW-1:0]       ram [RAM_DP-1:0];
    reg  [RAM_DW-1:0]       qr;
    wire                    wr;
    wire                    rd;
    wire [BYTE_NUM-1:0]     wm;

    assign wr = ce & we;
    assign rd = ce & (~we);
    
    generate
        for (i = 0; i < BYTE_NUM; i = i + 1) begin: gen_wm
            if (i < RAM_MW) begin: gen_low_wm
                assign wm[i] = wr & m[i];
            end
            else begin: gen_high_wm
                assign wm[i] = wr;
            end
        end
    endgenerate
    
    generate
        if (RAM_ME) begin: gen_ram_wr_me
            for (i = 0; i < BYTE_NUM; i = i + 1) begin: gen_ram_wr
                if (RAM_DLY == 0) begin: gen_ram_wr_without_dly
                    always @(posedge clk) begin
                        if (wm[i]) begin
                            ram[a][8*(i+1)-1:8*i] <= #UDLY d[8*(i+1)-1:8*i];
                        end
                    end
                end
                else begin: gen_ram_wr_with_dly
                    always @(posedge clk) begin
                        if (wm[i]) begin
                            repeat(RAM_DLY) @(posedge clk);
                            ram[a][8*(i+1)-1:8*i] <= #UDLY d[8*(i+1)-1:8*i];
                        end
                    end
                end
            end
            end
        else begin: gen_ram_wr_men
            if (RAM_DLY == 0) begin: gen_ram_wr_without_dly
                always @(posedge clk) begin
                    if (wr) begin
                        ram[a] <= #UDLY d;
                    end
                end
            end
            else begin: gen_ram_wr_with_dly
                always @(posedge clk) begin
                    if (wr) begin
                        repeat(RAM_DLY) @(posedge clk);
                        ram[a] <= #UDLY d;
                    end
                end
            end
        end
    endgenerate
    
    generate
        if (RAM_DLY == 0) begin: gen_ram_rd_without_dly
            always @(posedge clk) begin
                if (rd) begin
                    qr <= #UDLY ram[a];
                end
            end
        end
        else begin: gen_ram_rd_with_dly
            always @(posedge clk) begin
                if (rd) begin
                    repeat(RAM_DLY) @(posedge clk);
                    qr <= #UDLY ram[a];
                end
            end
        end
    endgenerate
    
    assign q = qr;

endmodule

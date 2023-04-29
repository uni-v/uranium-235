//************************************************************
// See LICENSE for license details.
//
// Module: tb_top
//
// Designer: Owen
//
// Description:
//      Top module for testbench.
//************************************************************

`timescale 1ns / 1ps

module tb_top;

`ifdef UDLY
    localparam UDLY   = `UDLY;
`else
    localparam UDLY   = 1;
`endif
localparam CLK_PERIOD = 10;
localparam LCK_PERIOD = CLK_PERIOD * 10;
localparam RST_CYCLES = 10;
localparam MAX_CYCLES = 1000000000;
localparam DEFAULT_SEED = 37;

reg  clk;
reg  lck;
reg  rst_n;
reg  rst_done;
reg  SIM_END;
time seed;

`include "tb_task.v"
`include "tb_dut.v"

// Seed.
initial begin
    if (!$value$plusargs("SEED=%d", seed)) begin
        seed = DEFAULT_SEED;
        $display("Warning: There is no random seed specified. Use default seed %0d!", seed);
    end
    //$display("> SIM SEED: %0d", seed);
end

// Clock.
initial begin
    clk = 1'b0;
    #({$random(seed)} % CLK_PERIOD)
    forever #(CLK_PERIOD / 2.0) clk = ~clk;
end

// Low-freq Clock.
initial begin
    lck = 1'b0;
    #({$random(seed)} % LCK_PERIOD)
    forever #(LCK_PERIOD / 2.0) lck = ~lck;
end

// Reset.
initial begin
    rst_done = 1'b0;
    rst_n    = 1'b1;
    #CLK_PERIOD
    #({$random(seed)} % CLK_PERIOD)
    rst_n    = 1'b0;
    #(CLK_PERIOD * RST_CYCLES)
    rst_n    = 1'b1;
    rst_done = 1'b1;
end

// Timeout.
initial begin
`ifndef SIM_FOREVER
    #(CLK_PERIOD * MAX_CYCLES)
    SIM_END = 1'b1;
`endif
end

// Finish.
initial begin
    SIM_END = 1'b0;
    wait (SIM_END);
    #100;
    $finish;
end

// Dump wave.
initial begin
`ifdef DUMP_NONE
    // No WAVE.
`elsif DUMP_VPD
    $vcdplusfile("tb_top.vpd");
    $vcdpluson;
`elsif DUMP_FSDB
    $fsdbDumpfile("tb_top.fsdb");
    $fsdbDumpvars(0, tb_top);
`else
    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);
`endif
end

endmodule

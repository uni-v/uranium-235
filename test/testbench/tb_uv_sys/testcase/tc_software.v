// See LICENSE for license details.

// Case: Run softwares.

`include "tb_mem.v"

localparam PRINT_ADDR = 32'h08000028;
localparam EXIT_ADDR  = 32'h08000028;
localparam EXIT_DATA  = 32'hcafe0235;

wire [31:0] pc;
wire [31:0] ra;
wire [31:0] sp;
wire [31:0] gp;
wire [31:0] tp;
wire [31:0] t0;
wire [31:0] t1;
wire [31:0] t2;
wire [31:0] s0;
wire [31:0] s1;
wire [31:0] a0;
wire [31:0] a1;
wire [31:0] a2;
wire [31:0] a3;
wire [31:0] a4;
wire [31:0] a5;
wire [31:0] a6;
wire [31:0] a7;
wire [31:0] s2;
wire [31:0] s3;
wire [31:0] s4;
wire [31:0] s5;
wire [31:0] s6;
wire [31:0] s7;
wire [31:0] s8;
wire [31:0] s9;
wire [31:0] s10;
wire [31:0] s11;
wire [31:0] t3;
wire [31:0] t4;
wire [31:0] t5;
wire [31:0] t6;
reg         riscv_test_end;

reg  [31:0] magic_addr;
reg  [31:0] magic_data;
reg  [31:0] print_addr;
reg  [31:0] print_data;
reg  [31:0] print_len;
reg  [31:0] print_idx;

reg  [MAX_STRING_LEN*8-1:0] rf_log_filename;
integer fp_rf_log;

assign pc   = `IFU.pc_r;
assign ra   = `RF.rf[1];
assign sp   = `RF.rf[2];
assign gp   = `RF.rf[3];
assign tp   = `RF.rf[4];
assign t0   = `RF.rf[5];
assign t1   = `RF.rf[6];
assign t2   = `RF.rf[7];
assign s0   = `RF.rf[8];
assign s1   = `RF.rf[9];
assign a0   = `RF.rf[10];
assign a1   = `RF.rf[11];
assign a2   = `RF.rf[12];
assign a3   = `RF.rf[13];
assign a4   = `RF.rf[14];
assign a5   = `RF.rf[15];
assign a6   = `RF.rf[16];
assign a7   = `RF.rf[17];
assign s2   = `RF.rf[18];
assign s3   = `RF.rf[19];
assign s4   = `RF.rf[20];
assign s5   = `RF.rf[21];
assign s6   = `RF.rf[22];
assign s7   = `RF.rf[23];
assign s8   = `RF.rf[24];
assign s9   = `RF.rf[25];
assign s10  = `RF.rf[26];
assign s11  = `RF.rf[27];
assign t3   = `RF.rf[28];
assign t4   = `RF.rf[29];
assign t5   = `RF.rf[30];
assign t6   = `RF.rf[31];

always @(posedge clk) begin
    if (`LSU.ls2mem_req_vld && `LSU.ls2mem_req_rdy && (!`LSU.ls2mem_req_read)
        && (`LSU.ls2mem_req_addr == PRINT_ADDR) && (`LSU.ls2mem_req_mask == 4'h1)) begin
        $write("%s", `LSU.ls2mem_req_data[7:0]);
    end
end

initial begin
    wait (`LSU.ls2mem_req_vld && `LSU.ls2mem_req_rdy && (!`LSU.ls2mem_req_read)
        && (`LSU.ls2mem_req_addr == EXIT_ADDR) && (`LSU.ls2mem_req_mask == 4'hf)
        && (`LSU.ls2mem_req_data == EXIT_DATA)) begin
        tb_delay(100);
        SIM_END = 1'b1;
    end
end

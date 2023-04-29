// See LICENSE for license details.

// Case: Run riscv-tests.

`include "tb_mem.v"

localparam PRINT_DELAY   = 10;
localparam FROMHOST_ADDR = 32'h80001040;
localparam TOHOST_ADDR   = 32'h80001000;
localparam TOHOST_SYS    = 32'h64;
localparam TOHOST_END    = 32'h235;

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
reg         sim_with_error;
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

//task read_dam;
//    input  [31:0]   addr;
//    output [31:0]   data;
//begin
//    if (addr & 32'h80000000) begin
//        if (addr[15:0] < 16'h8000) begin
//            data = `INST_MEM[addr[15:0]];
//        end
//        else begin
//            data = `DATA_MEM[addr[15:0] - 16'h8000];
//        end
//    end
//    else begin
//        $display("Fatal: Unexpected DAM reading address 0x%08h!", addr);
//        sim_with_error = 1'b1;
//        SIM_END = 1'b1;
//    end
//end
//endtask

//task write_dam;
//    input  [31:0]   addr;
//    input  [31:0]   data;
//begin
//    if (addr & 32'h80000000) begin
//        if (addr[15:0] < 16'h8000) begin
//            `INST_MEM[addr[15:0]] = data;
//        end
//        else begin
//            `DATA_MEM[addr[15:0] - 16'h8000] = data;
//        end
//    end
//    else begin
//        $display("Fatal: Unexpected DAM writing address 0x%08h!", addr);
//        sim_with_error = 1'b1;
//        SIM_END = 1'b1;
//    end
//end
//endtask

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        riscv_test_end <= 1'b0;
    end
    else begin
        if (`LSU.ls2mem_req_vld && `LSU.ls2mem_req_rdy && (!`LSU.ls2mem_req_read)
            && (`LSU.ls2mem_req_addr == TOHOST_ADDR)) begin
            if (`LSU.ls2mem_req_data == TOHOST_END) begin
                riscv_test_end <= 1'b1;
            end
            else begin
                read_dam(TOHOST_ADDR, magic_addr);
                read_dam(magic_addr, magic_data);
                if (magic_data == TOHOST_SYS) begin
                    read_dam(magic_addr + 32'd16, print_addr);
                    read_dam(magic_addr + 32'd24, print_len);
                    for (print_idx = 32'd0; print_idx + 32'd4 < print_len; print_idx = print_idx + 4) begin
                        read_dam(print_addr + print_idx, print_data);
                        $write("%s", print_data);
                    end
                    read_dam(print_addr + print_idx, print_data);
                    while (print_idx < print_len) begin
                        $write("%s", print_data[7:0]);
                        print_data = {8'h0, print_data[31:8]};
                        print_idx = print_idx + 32'd1;
                    end
                    // Feedback to application.
                    tb_delay(PRINT_DELAY);
                    write_dam(FROMHOST_ADDR, 32'h1);
                end
            end
        end
    end
end

initial begin
    sim_with_error = 1'b0;
    wait (rst_done);
    wait (riscv_test_end);

    if (gp == 32'd1) begin
        $display("+++++++++++ PASS +++++++++++");
    end
    else begin
        $display("xxxxxxxxxxx FAIL xxxxxxxxxxx");
    end
    
    //$sformat(rf_log_filename, "./log/riscv_tests_rf_val_%s.log", sti_name);
    //fp_rf_log = $fopen(rf_log_filename, "w");
    //$fdisplay(fp_rf_log, "    x0  (zero)    :    0x%h", `RF.rf[0]);
    //$fdisplay(fp_rf_log, "    x1  (ra)      :    0x%h", `RF.rf[1]);
    //$fdisplay(fp_rf_log, "    x2  (sp)      :    0x%h", `RF.rf[2]);
    //$fdisplay(fp_rf_log, "    x3  (gp)      :    0x%h", `RF.rf[3]);
    //$fdisplay(fp_rf_log, "    x4  (tp)      :    0x%h", `RF.rf[4]);
    //$fdisplay(fp_rf_log, "    x5  (t0)      :    0x%h", `RF.rf[5]);
    //$fdisplay(fp_rf_log, "    x6  (t1)      :    0x%h", `RF.rf[6]);
    //$fdisplay(fp_rf_log, "    x7  (t2)      :    0x%h", `RF.rf[7]);
    //$fdisplay(fp_rf_log, "    x8  (s0/fp)   :    0x%h", `RF.rf[8]);
    //$fdisplay(fp_rf_log, "    x9  (s1)      :    0x%h", `RF.rf[9]);
    //$fdisplay(fp_rf_log, "    x10 (a0)      :    0x%h", `RF.rf[10]);
    //$fdisplay(fp_rf_log, "    x11 (a1)      :    0x%h", `RF.rf[11]);
    //$fdisplay(fp_rf_log, "    x12 (a2)      :    0x%h", `RF.rf[12]);
    //$fdisplay(fp_rf_log, "    x13 (a3)      :    0x%h", `RF.rf[13]);
    //$fdisplay(fp_rf_log, "    x14 (a4)      :    0x%h", `RF.rf[14]);
    //$fdisplay(fp_rf_log, "    x15 (a5)      :    0x%h", `RF.rf[15]);
    //$fdisplay(fp_rf_log, "    x16 (a6)      :    0x%h", `RF.rf[16]);
    //$fdisplay(fp_rf_log, "    x17 (a7)      :    0x%h", `RF.rf[17]);
    //$fdisplay(fp_rf_log, "    x18 (s2)      :    0x%h", `RF.rf[18]);
    //$fdisplay(fp_rf_log, "    x19 (s3)      :    0x%h", `RF.rf[19]);
    //$fdisplay(fp_rf_log, "    x20 (s4)      :    0x%h", `RF.rf[20]);
    //$fdisplay(fp_rf_log, "    x21 (s5)      :    0x%h", `RF.rf[21]);
    //$fdisplay(fp_rf_log, "    x22 (s6)      :    0x%h", `RF.rf[22]);
    //$fdisplay(fp_rf_log, "    x23 (s7)      :    0x%h", `RF.rf[23]);
    //$fdisplay(fp_rf_log, "    x24 (s8)      :    0x%h", `RF.rf[24]);
    //$fdisplay(fp_rf_log, "    x25 (s9)      :    0x%h", `RF.rf[25]);
    //$fdisplay(fp_rf_log, "    x26 (s10)     :    0x%h", `RF.rf[26]);
    //$fdisplay(fp_rf_log, "    x27 (s11)     :    0x%h", `RF.rf[27]);
    //$fdisplay(fp_rf_log, "    x28 (t3)      :    0x%h", `RF.rf[28]);
    //$fdisplay(fp_rf_log, "    x29 (t4)      :    0x%h", `RF.rf[29]);
    //$fdisplay(fp_rf_log, "    x30 (t5)      :    0x%h", `RF.rf[30]);
    //$fdisplay(fp_rf_log, "    x31 (t6)      :    0x%h", `RF.rf[31]);

    tb_delay(10);
    $finish;
end

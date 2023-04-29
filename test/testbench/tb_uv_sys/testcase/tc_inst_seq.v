// See LICENSE for license details.

// Case: Test instruction sequence.

`include "tb_mem.v"

localparam END_INST_LOOP_NUM = 30;
integer fp_inst_seq_rf_val;

initial begin
    wait (rst_done);
    wait (SIM_END);
    $display("Regfile Values:");
    // for (i = 0; i < 32; i = i + 1) begin
    //     $display("\tx%0d\t:\t0x%h", i, `RF.rf[i]);
    // end
    $display("    x0  (zero)    :    0x%h", `RF.rf[0]);
    $display("    x1  (ra)      :    0x%h", `RF.rf[1]);
    $display("    x2  (sp)      :    0x%h", `RF.rf[2]);
    $display("    x3  (gp)      :    0x%h", `RF.rf[3]);
    $display("    x4  (tp)      :    0x%h", `RF.rf[4]);
    $display("    x5  (t0)      :    0x%h", `RF.rf[5]);
    $display("    x6  (t1)      :    0x%h", `RF.rf[6]);
    $display("    x7  (t2)      :    0x%h", `RF.rf[7]);
    $display("    x8  (s0/fp)   :    0x%h", `RF.rf[8]);
    $display("    x9  (s1)      :    0x%h", `RF.rf[9]);
    $display("    x10 (a0)      :    0x%h", `RF.rf[10]);
    $display("    x11 (a1)      :    0x%h", `RF.rf[11]);
    $display("    x12 (a2)      :    0x%h", `RF.rf[12]);
    $display("    x13 (a3)      :    0x%h", `RF.rf[13]);
    $display("    x14 (a4)      :    0x%h", `RF.rf[14]);
    $display("    x15 (a5)      :    0x%h", `RF.rf[15]);
    $display("    x16 (a6)      :    0x%h", `RF.rf[16]);
    $display("    x17 (a7)      :    0x%h", `RF.rf[17]);
    $display("    x18 (s2)      :    0x%h", `RF.rf[18]);
    $display("    x19 (s3)      :    0x%h", `RF.rf[19]);
    $display("    x20 (s4)      :    0x%h", `RF.rf[20]);
    $display("    x21 (s5)      :    0x%h", `RF.rf[21]);
    $display("    x22 (s6)      :    0x%h", `RF.rf[22]);
    $display("    x23 (s7)      :    0x%h", `RF.rf[23]);
    $display("    x24 (s8)      :    0x%h", `RF.rf[24]);
    $display("    x25 (s9)      :    0x%h", `RF.rf[25]);
    $display("    x26 (s10)     :    0x%h", `RF.rf[26]);
    $display("    x27 (s11)     :    0x%h", `RF.rf[27]);
    $display("    x28 (t3)      :    0x%h", `RF.rf[28]);
    $display("    x29 (t4)      :    0x%h", `RF.rf[29]);
    $display("    x30 (t5)      :    0x%h", `RF.rf[30]);
    $display("    x31 (t6)      :    0x%h", `RF.rf[31]);

    fp_inst_seq_rf_val = $fopen("./log/inst_seq_rf_val.log");
    $fdisplay(fp_inst_seq_rf_val, "    x0  (zero)    :    0x%h", `RF.rf[0]);
    $fdisplay(fp_inst_seq_rf_val, "    x1  (ra)      :    0x%h", `RF.rf[1]);
    $fdisplay(fp_inst_seq_rf_val, "    x2  (sp)      :    0x%h", `RF.rf[2]);
    $fdisplay(fp_inst_seq_rf_val, "    x3  (gp)      :    0x%h", `RF.rf[3]);
    $fdisplay(fp_inst_seq_rf_val, "    x4  (tp)      :    0x%h", `RF.rf[4]);
    $fdisplay(fp_inst_seq_rf_val, "    x5  (t0)      :    0x%h", `RF.rf[5]);
    $fdisplay(fp_inst_seq_rf_val, "    x6  (t1)      :    0x%h", `RF.rf[6]);
    $fdisplay(fp_inst_seq_rf_val, "    x7  (t2)      :    0x%h", `RF.rf[7]);
    $fdisplay(fp_inst_seq_rf_val, "    x8  (s0/fp)   :    0x%h", `RF.rf[8]);
    $fdisplay(fp_inst_seq_rf_val, "    x9  (s1)      :    0x%h", `RF.rf[9]);
    $fdisplay(fp_inst_seq_rf_val, "    x10 (a0)      :    0x%h", `RF.rf[10]);
    $fdisplay(fp_inst_seq_rf_val, "    x11 (a1)      :    0x%h", `RF.rf[11]);
    $fdisplay(fp_inst_seq_rf_val, "    x12 (a2)      :    0x%h", `RF.rf[12]);
    $fdisplay(fp_inst_seq_rf_val, "    x13 (a3)      :    0x%h", `RF.rf[13]);
    $fdisplay(fp_inst_seq_rf_val, "    x14 (a4)      :    0x%h", `RF.rf[14]);
    $fdisplay(fp_inst_seq_rf_val, "    x15 (a5)      :    0x%h", `RF.rf[15]);
    $fdisplay(fp_inst_seq_rf_val, "    x16 (a6)      :    0x%h", `RF.rf[16]);
    $fdisplay(fp_inst_seq_rf_val, "    x17 (a7)      :    0x%h", `RF.rf[17]);
    $fdisplay(fp_inst_seq_rf_val, "    x18 (s2)      :    0x%h", `RF.rf[18]);
    $fdisplay(fp_inst_seq_rf_val, "    x19 (s3)      :    0x%h", `RF.rf[19]);
    $fdisplay(fp_inst_seq_rf_val, "    x20 (s4)      :    0x%h", `RF.rf[20]);
    $fdisplay(fp_inst_seq_rf_val, "    x21 (s5)      :    0x%h", `RF.rf[21]);
    $fdisplay(fp_inst_seq_rf_val, "    x22 (s6)      :    0x%h", `RF.rf[22]);
    $fdisplay(fp_inst_seq_rf_val, "    x23 (s7)      :    0x%h", `RF.rf[23]);
    $fdisplay(fp_inst_seq_rf_val, "    x24 (s8)      :    0x%h", `RF.rf[24]);
    $fdisplay(fp_inst_seq_rf_val, "    x25 (s9)      :    0x%h", `RF.rf[25]);
    $fdisplay(fp_inst_seq_rf_val, "    x26 (s10)     :    0x%h", `RF.rf[26]);
    $fdisplay(fp_inst_seq_rf_val, "    x27 (s11)     :    0x%h", `RF.rf[27]);
    $fdisplay(fp_inst_seq_rf_val, "    x28 (t3)      :    0x%h", `RF.rf[28]);
    $fdisplay(fp_inst_seq_rf_val, "    x29 (t4)      :    0x%h", `RF.rf[29]);
    $fdisplay(fp_inst_seq_rf_val, "    x30 (t5)      :    0x%h", `RF.rf[30]);
    $fdisplay(fp_inst_seq_rf_val, "    x31 (t6)      :    0x%h", `RF.rf[31]);

    $finish;
end

reg end_inst;
initial begin
    wait (rst_done);
    repeat (END_INST_LOOP_NUM) begin
        end_inst = 1'b0;
        while (~end_inst) begin
            @(posedge clk);
            if (DUT.dam_i_rsp_vld & DUT.dam_i_rsp_rdy) begin
                @(posedge clk);
                if (DUT.dam_i_rsp_data == 32'h6f) begin
                    end_inst = 1'b1;
                end
            end
        end
    end
    SIM_END = 1'b1;
end

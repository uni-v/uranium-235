//************************************************************
// See LICENSE for license details.
//
// Module: uv_ifu
//
// Designer: Owen
//
// Description:
//      Instruction Fetching Unit.
//      FIXME: Multiple outstanding requests.
//************************************************************

`timescale 1ns / 1ps

module uv_ifu
#(
    parameter ALEN = 32,
    parameter ILEN = 32,
    parameter XLEN = 32
)
(
    input                   clk,
    input                   rst_n,
    
    // Memory reading.
    output                  if2mem_req_vld,
    input                   if2mem_req_rdy,
    output [ALEN-1:0]       if2mem_req_addr,

    input                   if2mem_rsp_vld,
    output                  if2mem_rsp_rdy,
    input  [1:0]            if2mem_rsp_excp,
    input  [ILEN-1:0]       if2mem_rsp_data,

    // Request to BPU.
    output                  if2bp_vld,
    output [ALEN-1:0]       if2bp_pc,
    output [ILEN-1:0]       if2bp_inst,
    output                  if2bp_stall,

    // Prediction from BPU.
    input                   bp2if_br_tak,
    input                   bp2if_pc_vld,
    input  [ALEN-1:0]       bp2if_pc_nxt,
    
    // IDU handshake.
    output                  if2id_vld,
    input                   if2id_rdy,
    
    // Request to IDU.
    output [ILEN-1:0]       if2id_inst,
    output [ALEN-1:0]       if2id_pc,
    output [ALEN-1:0]       if2id_pc_nxt,
    output                  if2id_br_tak,

    output                  if2id_has_excp,
    output                  if2id_acc_fault,
    output                  if2id_mis_align,
    
    // Flush control from bjp misprediction.
    input                   id_br_flush,
    input                   ex_br_flush,

    // Flush control from trap.
    input                   trap_flush,

    // Flush control by instruction.
    input                   fence_inst,

    // Redirection for bjp misprediction.
    input                   id2if_bjp_vld,
    input  [ALEN-1:0]       id2if_bjp_addr,

    input                   ex2if_bjp_vld,
    input  [ALEN-1:0]       ex2if_bjp_addr,

    // Redirection for trap.
    input                   cm2if_trap_vld,
    input  [ALEN-1:0]       cm2if_trap_addr
);

    localparam UDLY         = 1;
    
    // Pipeline control.
    wire                    pipe_flush;
    wire                    pipe_nxt;

    // Handshakes.
    reg                     if2id_vld_r;
    reg                     if2id_rdy_r;
    reg                     if2bp_rdy_r;
    
    // PC & Instruction.
    wire                    pc_vld;
    wire [ALEN-1:0]         pc_nxt;
    
    reg  [ALEN-1:0]         pc_r;
    reg                     pc_vld_r;

    reg  [ALEN-1:0]         pc_cur_t;
    reg  [ALEN-1:0]         pc_cur_tt;
    reg  [ALEN-1:0]         pc_cur_r;
    reg  [1:0]              pc_cur_mask_r;

    reg  [ALEN-1:0]         pc_nxt_t;
    reg  [ALEN-1:0]         pc_nxt_tt;
    reg  [ALEN-1:0]         pc_nxt_r;
    reg  [1:0]              pc_nxt_mask_r;

    reg                     br_tak_t;
    reg                     br_tak_tt;
    reg  [1:0]              br_tak_mask_r;
    reg                     br_tak_r;
    
    wire                    inst_rdy;
    reg                     inst_rdy_r;
    reg  [ILEN-1:0]         inst_r;
    reg  [ILEN-1:0]         inst_rr;
    reg  [ILEN-1:0]         inst_t;
    reg  [ILEN-1:0]         inst_tt;
    reg  [1:0]              inst_mask_r;

    reg  [ILEN-1:0]         bp_inst_t;
    reg  [ILEN-1:0]         bp_inst_tt;
    reg  [1:0]              bp_inst_mask_r;
    
    // Stall & flush.
    wire                    if_stall;
    wire                    inst_flush;

    // Memory req & rsp.
    wire                    mem_req;
    reg                     mem_req_r;

    wire                    if2mem_req_wait;
    wire                    if2mem_req_fire;
    wire                    if2mem_rsp_fire;

    // Exceptions.
    reg                     acc_fault_r;
    reg                     mis_align_r;

    reg                     acc_fault_t;
    reg                     mis_align_t;
    
    // Control pipeline.
    assign pipe_flush       = id_br_flush | ex_br_flush | trap_flush | fence_inst;
    assign pipe_nxt         = if2id_rdy | (~if2id_vld);

    // Set stalling status.
    assign if_stall         = 1'b0;
    
    // Get PC.
    assign pc_vld           = cm2if_trap_vld | ex2if_bjp_vld | id2if_bjp_vld | bp2if_pc_vld;
    assign pc_nxt           = cm2if_trap_vld ? cm2if_trap_addr
                            : ex2if_bjp_vld  ? ex2if_bjp_addr
                            : id2if_bjp_vld  ? id2if_bjp_addr
                            : bp2if_pc_nxt;
    
    // Set bpu ports.
    // assign if2bp_vld        = inst_rdy & if2id_rdy;
    assign if2bp_vld        = (if2mem_rsp_fire | (|bp_inst_mask_r)) & if2id_rdy_r;
    assign if2bp_pc         = pc_r;
    // assign if2bp_inst       = if2mem_rsp_fire ? if2mem_rsp_data : inst_t;
    assign if2bp_inst       = bp_inst_mask_r[0] ? bp_inst_t
                            : bp_inst_mask_r[1] ? bp_inst_tt
                            : if2mem_rsp_data;
    assign if2bp_stall      = ~if2id_rdy_r;
    
    // Set memory request.
    //assign mem_req        = if2id_rdy & (~if_stall) & pc_vld;
    assign mem_req          = pc_vld & (~if_stall);
    assign if2mem_req_vld   = mem_req | mem_req_r;
    assign if2mem_req_addr  = pc_vld ? pc_nxt : pc_r;
    assign if2mem_req_wait  = if2mem_req_vld & ~if2mem_req_rdy;
    assign if2mem_req_fire  = if2mem_req_vld & if2mem_req_rdy;

    // Get Instruction.
    assign if2mem_rsp_rdy   = 1'b1;
    assign if2mem_rsp_fire  = if2mem_rsp_vld & if2mem_rsp_rdy;
    assign inst_rdy         = if2mem_rsp_fire | (|inst_mask_r);
    
    // Set IDU ports.
    assign if2id_vld        = if2id_vld_r & (~pipe_flush);
    assign if2id_inst       = inst_r;
    assign if2id_pc         = pc_cur_r;
    assign if2id_pc_nxt     = pc_nxt_r;
    assign if2id_br_tak     = br_tak_r;

    assign if2id_has_excp   = if2id_acc_fault | if2id_mis_align;
    assign if2id_acc_fault  = acc_fault_r;
    assign if2id_mis_align  = mis_align_r;
    
    // Buffer handshake request.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            if2id_vld_r <= 1'b0;
        end
        else begin
            if (inst_rdy & (~pipe_flush)) begin
                if2id_vld_r <= #UDLY 1'b1;
            end
            else if (if2id_rdy | pipe_flush) begin
                if2id_vld_r <= #UDLY 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            if2id_rdy_r <= 1'b0;
        end
        else begin
            if2id_rdy_r <= #UDLY if2id_rdy;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            if2bp_rdy_r <= 1'b0;
        end
        else begin
            if2bp_rdy_r <= #UDLY (~if2bp_vld) | if2id_rdy;
        end
    end

    // Buffer the current & previous PC.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            pc_vld_r <= 1'b0;
        end
        else begin
            pc_vld_r <= #UDLY pc_vld;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            pc_r <= {ALEN{1'b0}};
        end
        else begin
            if (pc_vld) begin
                pc_r <= #UDLY pc_nxt;
            end
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            pc_cur_r <= {ALEN{1'b0}};
        end
        else begin
            if (inst_rdy & pipe_nxt) begin
            //if (inst_rdy) begin
                pc_cur_r <= #UDLY pc_cur_mask_r[0] ? pc_cur_t
                                : pc_cur_mask_r[1] ? pc_cur_tt
                                : pc_r;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            pc_cur_t  <= {ALEN{1'b0}};
            pc_cur_tt <= {ALEN{1'b0}};
        end
        else begin
            if (~pipe_nxt) begin
                if (pc_vld_r & (~pc_cur_mask_r[0])) begin
                    pc_cur_t  <= #UDLY pc_r;
                end
                else if (pc_vld_r & pc_cur_mask_r[0]) begin
                    pc_cur_tt <= #UDLY pc_r;
                end
            end
            else begin
                if (pc_vld_r & pc_cur_mask_r[1]) begin
                    pc_cur_t  <= #UDLY pc_cur_tt;
                    pc_cur_tt <= #UDLY pc_r;
                end
                else if (pc_vld_r & pc_cur_mask_r[0]) begin
                    pc_cur_t  <= #UDLY pc_r;
                end
                else if ((~pc_vld_r) & pc_cur_mask_r[1]) begin
                    pc_cur_t  <= #UDLY pc_cur_tt;
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            pc_cur_mask_r <= 2'b00;
        end
        else begin
            if (pipe_flush) begin
                pc_cur_mask_r <= #UDLY 2'b00;
            end
            else if (~pipe_nxt) begin
                if (pc_vld_r & (~pc_cur_mask_r[0])) begin
                    pc_cur_mask_r <= #UDLY 2'b01;
                end
                else if (pc_vld_r & pc_cur_mask_r[0]) begin
                    pc_cur_mask_r <= #UDLY 2'b11;
                end
            end
            else begin
                if (pc_vld_r & pc_cur_mask_r[1]) begin
                    pc_cur_mask_r <= #UDLY 2'b11;
                end
                else if (pc_vld_r & pc_cur_mask_r[0]) begin
                    pc_cur_mask_r <= #UDLY 2'b01;
                end
                else if ((~pc_vld_r) & pc_cur_mask_r[1]) begin
                    pc_cur_mask_r <= #UDLY 2'b01;
                end
                else if ((~pc_vld_r) & pc_cur_mask_r[0]) begin
                    pc_cur_mask_r <= #UDLY 2'b00;
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            pc_nxt_r <= {ALEN{1'b0}};
        end
        else begin
            if (inst_rdy & pipe_nxt) begin
            //if (inst_rdy) begin
                pc_nxt_r <= #UDLY pc_nxt_mask_r[0] ? pc_nxt_t
                                : pc_nxt_mask_r[1] ? pc_nxt_tt
                                : pc_nxt;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            pc_nxt_t  <= {ALEN{1'b0}};
            pc_nxt_tt <= {ALEN{1'b0}};
        end
        else begin
            if (~pipe_nxt) begin
                if (pc_vld_r & (~pc_nxt_mask_r[0])) begin
                    pc_nxt_t  <= #UDLY pc_nxt;
                end
                else if (pc_vld_r & pc_cur_mask_r[0]) begin
                    pc_nxt_tt <= #UDLY pc_nxt;
                end
            end
            else begin
                if (pc_vld_r & pc_nxt_mask_r[1]) begin
                    pc_nxt_t  <= #UDLY pc_nxt_tt;
                    pc_nxt_tt <= #UDLY pc_nxt;
                end
                else if (pc_vld_r & pc_nxt_mask_r[0]) begin
                    pc_nxt_t  <= #UDLY pc_nxt;
                end
                else if ((~pc_vld_r) & pc_nxt_mask_r[1]) begin
                    pc_nxt_t  <= #UDLY pc_nxt_tt;
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            pc_nxt_mask_r <= 2'b00;
        end
        else begin
            if (pipe_flush) begin
                pc_nxt_mask_r <= #UDLY 2'b00;
            end
            else if (~pipe_nxt) begin
                if (pc_vld_r & (~pc_nxt_mask_r[0])) begin
                    pc_nxt_mask_r <= #UDLY 2'b01;
                end
                else if (pc_vld_r & pc_nxt_mask_r[0]) begin
                    pc_nxt_mask_r <= #UDLY 2'b11;
                end
            end
            else begin
                if (pc_vld_r & pc_nxt_mask_r[1]) begin
                    pc_nxt_mask_r <= #UDLY 2'b11;
                end
                else if (pc_vld_r & pc_nxt_mask_r[0]) begin
                    pc_nxt_mask_r <= #UDLY 2'b01;
                end
                else if ((~pc_vld_r) & pc_nxt_mask_r[1]) begin
                    pc_nxt_mask_r <= #UDLY 2'b01;
                end
                else if ((~pc_vld_r) & pc_nxt_mask_r[0]) begin
                    pc_nxt_mask_r <= #UDLY 2'b00;
                end
            end
        end
    end

    // Buffer branch taken flag.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            br_tak_r  <= 1'b0;
        end
        else begin
            if (inst_rdy & pipe_nxt) begin
            //if (inst_rdy) begin
                br_tak_r <= #UDLY br_tak_mask_r[0] ? br_tak_t
                                : br_tak_mask_r[1] ? br_tak_tt
                                : bp2if_br_tak;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            br_tak_t  <= 1'b0;
            br_tak_tt <= 1'b0;
        end
        else begin
            if (~pipe_nxt) begin
                if (bp2if_pc_vld & (~br_tak_mask_r[0])) begin
                    br_tak_t  <= #UDLY bp2if_br_tak;
                end
                else if (bp2if_pc_vld & br_tak_mask_r[0]) begin
                    br_tak_tt <= #UDLY bp2if_br_tak;
                end
            end
            else begin
                if (bp2if_pc_vld & br_tak_mask_r[1]) begin
                    br_tak_t  <= #UDLY br_tak_tt;
                    br_tak_tt <= #UDLY bp2if_br_tak;
                end
                else if (bp2if_pc_vld & br_tak_mask_r[0]) begin
                    br_tak_t  <= #UDLY bp2if_br_tak;
                end
                else if ((~bp2if_pc_vld) & br_tak_mask_r[1]) begin
                    br_tak_t  <= #UDLY br_tak_tt;
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            br_tak_mask_r <= 2'b00;
        end
        else begin
            if (pipe_flush) begin
                br_tak_mask_r <= #UDLY 2'b00;
            end
            else if (~pipe_nxt) begin
                if (bp2if_pc_vld & (~br_tak_mask_r[0])) begin
                    br_tak_mask_r <= #UDLY 2'b01;
                end
                else if (bp2if_pc_vld & br_tak_mask_r[0]) begin
                    br_tak_mask_r <= #UDLY 2'b11;
                end
            end
            else begin
                if (bp2if_pc_vld & br_tak_mask_r[1]) begin
                    br_tak_mask_r <= #UDLY 2'b11;
                end
                else if (bp2if_pc_vld & br_tak_mask_r[0]) begin
                    br_tak_mask_r <= #UDLY 2'b01;
                end
                else if ((~bp2if_pc_vld) & br_tak_mask_r[1]) begin
                    br_tak_mask_r <= #UDLY 2'b01;
                end
                else if ((~bp2if_pc_vld) & br_tak_mask_r[0]) begin
                    br_tak_mask_r <= #UDLY 2'b00;
                end
            end
        end
    end

    // Buffer the instruction to be decoded.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            inst_r <= {ILEN{1'b0}};
        end
        else begin
            if (inst_rdy & pipe_nxt) begin
            //if (inst_rdy) begin
                // inst_r <= #UDLY if2mem_rsp_fire ? if2mem_rsp_data : inst_t;
                inst_r <= #UDLY inst_mask_r[0] ? inst_t
                              : inst_mask_r[1] ? inst_tt
                              : if2mem_rsp_data;
            end
        end
    end

    // Buffer the rsp instruction in time.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            inst_t  <= {ILEN{1'b0}};
            inst_tt <= {ILEN{1'b0}};
        end
        else begin
            if (~pipe_nxt) begin
                if (if2mem_rsp_fire & (~inst_mask_r[0])) begin
                    inst_t  <= #UDLY if2mem_rsp_data;
                end
                else if (if2mem_rsp_fire & inst_mask_r[0]) begin
                    inst_tt <= #UDLY if2mem_rsp_data;
                end
                else if (if2mem_rsp_fire) begin
                    $display("Error!");
                end
            end
            else begin
                if (if2mem_rsp_fire & inst_mask_r[1]) begin
                    inst_t  <= #UDLY inst_tt;
                    inst_tt <= #UDLY if2mem_rsp_data;
                end
                else if (if2mem_rsp_fire & inst_mask_r[0]) begin
                    inst_t  <= #UDLY if2mem_rsp_data;
                end
                else if ((~if2mem_rsp_fire) & inst_mask_r[1]) begin
                    inst_t  <= #UDLY inst_tt;
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            inst_mask_r <= 2'b00;
        end
        else begin
            if (pipe_flush) begin
                inst_mask_r <= #UDLY 2'b00;
            end
            else if (~pipe_nxt) begin
                if (if2mem_rsp_fire & (~inst_mask_r[0])) begin
                    inst_mask_r <= #UDLY 2'b01;
                end
                else if (if2mem_rsp_fire & inst_mask_r[0]) begin
                    inst_mask_r <= #UDLY 2'b11;
                end
                else if (if2mem_rsp_fire) begin
                    $display("Error!");
                end
            end
            else begin
                if (if2mem_rsp_fire & inst_mask_r[1]) begin
                    inst_mask_r <= #UDLY 2'b11;
                end
                else if (if2mem_rsp_fire & inst_mask_r[0]) begin
                    inst_mask_r <= #UDLY 2'b01;
                end
                else if ((~if2mem_rsp_fire) & inst_mask_r[1]) begin
                    inst_mask_r <= #UDLY 2'b01;
                end
                else if ((~if2mem_rsp_fire) & inst_mask_r[0]) begin
                    inst_mask_r <= #UDLY 2'b00;
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            bp_inst_t  <= {ILEN{1'b0}};
            bp_inst_tt <= {ILEN{1'b0}};
        end
        else begin
            if (~pc_vld) begin
                if (if2mem_rsp_fire & (~bp_inst_mask_r[0])) begin
                    bp_inst_t  <= #UDLY if2mem_rsp_data;
                end
                else if (if2mem_rsp_fire & bp_inst_mask_r[0]) begin
                    bp_inst_tt <= #UDLY if2mem_rsp_data;
                end
            end
            else begin
                if (if2mem_rsp_fire & bp_inst_mask_r[1]) begin
                    bp_inst_t  <= #UDLY bp_inst_tt;
                    bp_inst_tt <= #UDLY if2mem_rsp_data;
                end
                else if (if2mem_rsp_fire & bp_inst_mask_r[0]) begin
                    bp_inst_t  <= #UDLY if2mem_rsp_data;
                end
                else if ((~if2mem_rsp_fire) & bp_inst_mask_r[1]) begin
                    bp_inst_t  <= #UDLY bp_inst_tt;
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            bp_inst_mask_r <= 2'b00;
        end
        else begin
            if (pipe_flush) begin
                bp_inst_mask_r <= #UDLY 2'b00;
            end
            else if (~pc_vld) begin
                if (if2mem_rsp_fire & (~bp_inst_mask_r[0])) begin
                    bp_inst_mask_r <= #UDLY 2'b01;
                end
                else if (if2mem_rsp_fire & bp_inst_mask_r[0]) begin
                    bp_inst_mask_r <= #UDLY 2'b11;
                end
            end
            else begin
                if (if2mem_rsp_fire & bp_inst_mask_r[1]) begin
                    bp_inst_mask_r <= #UDLY 2'b11;
                end
                else if (if2mem_rsp_fire & bp_inst_mask_r[0]) begin
                    bp_inst_mask_r <= #UDLY 2'b01;
                end
                else if ((~if2mem_rsp_fire) & bp_inst_mask_r[1]) begin
                    bp_inst_mask_r <= #UDLY 2'b01;
                end
                else if ((~if2mem_rsp_fire) & bp_inst_mask_r[0]) begin
                    bp_inst_mask_r <= #UDLY 2'b00;
                end
            end
        end
    end

    // Buffer the excp to decoder.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            acc_fault_r <= 1'b0;
            mis_align_r <= 1'b0;
        end
        else begin
            if (inst_rdy & pipe_nxt) begin
            //if (inst_rdy) begin
                acc_fault_r <= #UDLY if2mem_rsp_fire ? if2mem_rsp_excp[0] : acc_fault_t;
                mis_align_r <= #UDLY if2mem_rsp_fire ? if2mem_rsp_excp[1] : mis_align_t;
            end
        end
    end

    // Buffer the rsp excp in time.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            acc_fault_t <= 1'b0;
            mis_align_t <= 1'b0;
        end
        else begin
            if (if2mem_rsp_fire) begin
                acc_fault_t <= #UDLY if2mem_rsp_excp[0];
                mis_align_t <= #UDLY if2mem_rsp_excp[1];
            end
        end
    end

    // Get instruction ready status.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            inst_rdy_r <= 1'b0;
        end
        else begin
            if (if2mem_rsp_fire & (~if2id_rdy)) begin
                inst_rdy_r <= #UDLY 1'b1;
            end
            else if (if2id_rdy) begin
                inst_rdy_r <= #UDLY 1'b0;
            end
        end
    end
    
    // Buffer mem request.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            mem_req_r <= 1'b0;
        end
        else begin
            if (if2mem_req_fire) begin
                mem_req_r <= #UDLY 1'b0;
            end
            else if (mem_req) begin
                mem_req_r <= #UDLY 1'b1;
            end
        end
    end

endmodule

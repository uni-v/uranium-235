//************************************************************
// See LICENSE for license details.
//
// Module: uv_queue
//
// Designer: Owen
//
// Description:
//      First-In-First-Out Queue.
//************************************************************

`timescale 1ns / 1ps

module uv_queue
#(
    parameter DAT_WIDTH         = 32,
    parameter PTR_WIDTH         = 3,
    parameter QUE_DEPTH         = 2**PTR_WIDTH,
    parameter ZERO_RDLY         = 1'b1  // 1'b0: delay 1 cycle after read fire; 1'b1: no delay.
)
(
    input                       clk,
    input                       rst_n,

    // Write channel.
    output                      wr_rdy,
    input                       wr_vld,
    input  [DAT_WIDTH-1:0]      wr_dat,

    // Read channel.
    output                      rd_rdy,
    input                       rd_vld,
    output [DAT_WIDTH-1:0]      rd_dat,

    // Control & status.
    input                       clr,
    output [PTR_WIDTH:0]        len,
    output                      full,
    output                      empty
);

    localparam UDLY             = 1;
    localparam LEN_WIDTH        = PTR_WIDTH + 1;
    localparam SUB_DEPTH        = QUE_DEPTH - 1;
    genvar i;

    reg  [DAT_WIDTH-1:0]        que [0:QUE_DEPTH-1];
    reg  [DAT_WIDTH-1:0]        rd_dat_r;

    reg                         wr_rdy_r;
    reg                         rd_rdy_r;

    reg  [PTR_WIDTH-1:0]        wr_ptr_r;
    reg  [PTR_WIDTH-1:0]        rd_ptr_r;
    reg  [LEN_WIDTH-1:0]        len_r;

    wire                        wr_fire;
    wire                        rd_fire;
    wire                        wr_only;
    wire                        rd_only;

    wire [PTR_WIDTH-1:0]        wr_ptr_add;
    wire [PTR_WIDTH-1:0]        rd_ptr_add;
    wire [PTR_WIDTH-1:0]        wr_ptr_nxt;
    wire [PTR_WIDTH-1:0]        rd_ptr_nxt;

    wire [LEN_WIDTH-1:0]        len_add;
    wire [LEN_WIDTH-1:0]        len_sub;

    wire                        will_be_full;
    wire                        will_be_empty;
    wire                        must_not_be_full;
    wire                        must_not_be_empty;

    // Response read data.
    assign rd_dat               = rd_dat_r;

    // Bypass request under illegal status.
    assign wr_fire              = wr_vld & (~full);
    assign rd_fire              = rd_vld & (~empty);
    assign wr_only              = wr_fire & (~rd_fire);
    assign rd_only              = rd_fire & (~wr_fire);

    // Calculate pointers.
    assign wr_ptr_add           = wr_ptr_r + 1'b1;
    assign rd_ptr_add           = rd_ptr_r + 1'b1;
    assign wr_ptr_nxt           = wr_ptr_add < QUE_DEPTH ? wr_ptr_add : {PTR_WIDTH{1'b0}};
    assign rd_ptr_nxt           = rd_ptr_add < QUE_DEPTH ? rd_ptr_add : {PTR_WIDTH{1'b0}};

    // Calculate length.
    assign len_add              = len_r + 1'b1;
    assign len_sub              = len_r - 1'b1;

    // Queue status.
    assign will_be_full         = (len_r == SUB_DEPTH[LEN_WIDTH-1:0]);
    assign will_be_empty        = (len_r == {{PTR_WIDTH{1'b0}}, 1'b1});
    assign must_not_be_full     = len_r < SUB_DEPTH[LEN_WIDTH-1:0];       
    assign must_not_be_empty    = len_r > {{PTR_WIDTH{1'b0}}, 1'b1};

    assign len                  = len_r;
    assign full                 = len_r == QUE_DEPTH[LEN_WIDTH-1:0];
    assign empty                = len_r == {LEN_WIDTH{1'b0}};

    // Back pressure.
    assign wr_rdy               = clr | must_not_be_full | (will_be_full & (~wr_only));
    assign rd_rdy               = (~clr) & (must_not_be_empty | (will_be_empty & (~rd_only)));

    // Write element to queue.
    always @(posedge clk) begin
        if (clr & wr_fire) begin
            que[0] <= #UDLY wr_dat;
        end
        else if ((~clr) & wr_fire) begin
            que[wr_ptr_r] <= #UDLY wr_dat;
        end
    end

    // Read element from queue.
    generate
        if (ZERO_RDLY) begin: gen_rdat_without_dly
            always @(*) begin
                rd_dat_r = que[rd_ptr_r];
            end
        end
        else begin: gen_rdat_without_dly
            always @(posedge clk) begin
                if (rd_fire) begin
                    rd_dat_r <= #UDLY que[rd_ptr_r];
                end
            end
        end
    endgenerate

    // Update written pointer.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            wr_ptr_r <= {PTR_WIDTH{1'b0}};
        end
        else begin
            if (clr & (~wr_fire)) begin
                wr_ptr_r <= #UDLY {PTR_WIDTH{1'b0}};
            end
            else if (clr & wr_fire) begin
                wr_ptr_r <= #UDLY {{(PTR_WIDTH-1){1'b0}}, 1'b1};
            end
            else if ((~clr) & wr_fire) begin
                wr_ptr_r <= #UDLY wr_ptr_nxt;
            end
        end
    end

    // Update read pointer.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            rd_ptr_r <= {PTR_WIDTH{1'b0}};
        end
        else begin
            if (clr) begin
                rd_ptr_r <= #UDLY {PTR_WIDTH{1'b0}};
            end
            else if (rd_fire) begin
                rd_ptr_r <= #UDLY rd_ptr_nxt;
            end
        end
    end

    // Update queue length.
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            len_r <= {LEN_WIDTH{1'b0}};
        end
        else begin
            if (clr) begin
                len_r <= #UDLY wr_fire ? {{(LEN_WIDTH-1){1'b0}}, 1'b1} : {LEN_WIDTH{1'b0}};
            end
            else if (wr_only) begin
                len_r <= #UDLY len_add;
            end
            else if (rd_only) begin
                len_r <= #UDLY len_sub;
            end
        end
    end

endmodule

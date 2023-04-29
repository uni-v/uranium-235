// See LICENSE for license details.

// Case: Test peripharals.

`include "tb_mem.v"

//-----------------------------------------------------------
// Common.
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

//-----------------------------------------------------------
// UART.
localparam UART_BAUD_RATE = 115200;
localparam UART_CFG_ADDR  = 12'h0;
localparam UART_RD_ADDR   = 12'h20;
localparam UART_WR_ADDR   = 12'h10;

reg                     uart_psel;
reg                     uart_penable;
reg  [2:0]              uart_pprot;
reg  [11:0]             uart_paddr;
reg  [3:0]              uart_pstrb;
reg                     uart_pwrite;
reg  [31:0]             uart_pwdata;
wire [31:0]             uart_prdata;
wire                    uart_pready;
wire                    uart_pslverr;

// Serial ports.
wire                    uart_tx;
wire                    uart_rx;

// UART data buffer.
reg  [31:0]             uart_loop_data;

// UART clock divider.
integer                 uart_clk_div;

// Connect UART to GPIO.
assign gpio_in[0]       = uart_tx;
assign uart_rx          = gpio_out[1];

// IRQ info.
wire [2:0] uart_pr      = `SLC.irq_pr_r[0];
wire [1:0] uart_tg      = `SLC.irq_tg_r[0];

// UART configs.
wire       uart_tx_en   = 1'b1;
wire       uart_rx_en   = 1'b1;
wire [1:0] uart_nbits   = 2'b11;

// APB operations.
task uart_apb_read;
    input  [11:0]       addr;
    output [31:0]       data;
begin
    uart_psel           = 1'b1;
    uart_penable        = 1'b0;
    uart_paddr          = addr;
    uart_pprot          = 3'b0;
    uart_pstrb          = 4'hf;
    uart_pwrite         = 1'b0;
    @(posedge clk);
    uart_penable        = 1'b1;
    @(posedge clk);
    while (!uart_pready) begin
        @(posedge clk);
    end
    data                = uart_prdata;
    #UDLY;
    uart_psel           = 1'b0;
end
endtask

task uart_apb_write;
    input  [11:0]       addr;
    input  [31:0]       data;
begin
    uart_psel           = 1'b1;
    uart_penable        = 1'b0;
    uart_paddr          = addr;
    uart_pprot          = 3'b0;
    uart_pstrb          = 4'hf;
    uart_pwrite         = 1'b1;
    uart_pwdata         = data;
    @(posedge clk);
    uart_penable        = 1'b1;
    @(posedge clk);
    while (!uart_pready) begin
        @(posedge clk);
    end
    #UDLY;
    uart_psel           = 1'b0;
end
endtask

initial begin
    wait (rst_done);
    uart_psel    = 1'b1;
    uart_penable = 1'b0;
    uart_paddr   = 12'b0;
    uart_pprot   = 3'b0;
    uart_pstrb   = 4'hf;
    uart_pwrite  = 1'b1;
    uart_pwdata  = 32'b0;
    uart_clk_div = 1000000000 / CLK_PERIOD / UART_BAUD_RATE;
    uart_apb_write(UART_CFG_ADDR, {uart_clk_div, 12'b0, uart_nbits, uart_rx_en, uart_tx_en});
    forever begin
        @(posedge clk);
        if (u_uart_adaptor.rx_deq_rdy) begin
            uart_apb_read (UART_RD_ADDR, uart_loop_data);
            uart_apb_write(UART_WR_ADDR, uart_loop_data);
        end
    end
end

// UART Adaptor.
// FIXME: It's better to use 3rd-party impl for cross verification.
uv_uart_apb u_uart_adaptor
(
    .clk                ( clk           ),
    .rst_n              ( rst_n         ),

    .uart_psel          ( uart_psel     ),
    .uart_penable       ( uart_penable  ),
    .uart_pprot         ( uart_pprot    ),
    .uart_paddr         ( uart_paddr    ),
    .uart_pstrb         ( uart_pstrb    ),
    .uart_pwrite        ( uart_pwrite   ),
    .uart_pwdata        ( uart_pwdata   ),
    .uart_prdata        ( uart_prdata   ),
    .uart_pready        ( uart_pready   ),
    .uart_pslverr       ( uart_pslverr  ),

    .uart_tx            ( uart_tx       ),
    .uart_rx            ( uart_rx       ),

    .uart_irq           ( uart_irq      )
);

//-----------------------------------------------------------
// SPI Slave.
// Serial ports.
wire                    spi_cs;
wire                    spi_sck;
wire                    spi_mosi;
wire                    spi_miso;

// Connect SPI to GPIO.
assign spi_cs           = gpio_out[2];
assign spi_sck          = gpio_out[3];
assign spi_mosi         = gpio_out[4];
assign gpio_in[5]       = spi_miso;

// IRQ info.
wire [2:0] spi_pr       = `SLC.irq_pr_r[1];
wire [1:0] spi_tg       = `SLC.irq_tg_r[1];

// Loop data to master.
assign spi_miso         = spi_mosi;

//-----------------------------------------------------------
// Tie unused IOs.
assign gpio_in[4:1]        = 4'b0;
assign gpio_in[IO_NUM-1:6] = {(IO_NUM-6){1'b0}};

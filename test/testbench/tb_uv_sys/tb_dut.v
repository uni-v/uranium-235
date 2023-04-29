// See LICENSE for license details.

`define CORE                    DUT.u_core
`define UCORE                   `CORE.u_ucore
`define IFU                     `UCORE.u_ifu
`define IDU                     `UCORE.u_idu
`define EXU                     `UCORE.u_exu
`define LSU                     `UCORE.u_lsu
`define CMT                     `UCORE.u_cmt
`define CSR                     `UCORE.u_csr
`define RF                      `UCORE.u_rf
`define ALU                     `UCORE.u_exu.u_alu

`define DAM                     DUT.gen_dam.u_dam
`define INST_MEM                `DAM.u_bank_a.ram
`define DATA_MEM                `DAM.u_bank_b.ram

`define DEV                     DUT.u_dev_subsys
`define SLC                     `DEV.u_slc
`define PRP                     `DEV.u_perip_subsys
`define UART                    `PRP.u_uart
`define SPI0                    `PRP.u_spi0
`define SPI1                    `PRP.u_spi1

localparam IO_NUM               = 32;
localparam MAX_STRING_LEN       = 256;
localparam INST_MEM_DEPTH       = 16384;

reg                             i2c_scl_in;
wire                            i2c_scl_out;
wire                            i2c_scl_oen;
reg                             i2c_sda_in;
wire                            i2c_sda_out;
wire                            i2c_sda_oen;

wire [IO_NUM-1:0]               gpio_pu;
wire [IO_NUM-1:0]               gpio_pd;
wire [IO_NUM-1:0]               gpio_ie;
wire [IO_NUM-1:0]               gpio_in;
wire [IO_NUM-1:0]               gpio_oe;
wire [IO_NUM-1:0]               gpio_out;

initial begin
    i2c_scl_in  = 1'b1;
    i2c_sda_in  = 1'b1;
end

string sti_name;
initial begin
    #1
    if ($value$plusargs("STI_NAME=%s", sti_name)) begin
        $display("> Stimulus: %s", sti_name);
    end
    else begin
        $display("> No stimulus!");
        $finish;
    end
end

// Testcase
`ifdef TC_INST_SEQ
    `include "tc_inst_seq.v"
`elsif TC_RISCV_TESTS
    `include "tc_riscv_tests.v"
`elsif TC_SOFTWARE
    `include "tc_software.v"
`elsif TC_PERIPS
    `include "tc_perips.v"
`else
    initial begin
        $display("No testcase!");
        $finish;
    end
`endif

//******************************
// DUT instantiation.
//******************************
uv_sys
#(
    .IO_NUM             ( IO_NUM            )
)
DUT
(
    .sys_clk            ( clk               ),
    .low_clk            ( lck               ),
    .sys_rst_n          ( rst_n             ),
    .por_rst_n          ( rst_n             ),

`ifdef USE_EXT_MEM
    // TODO.
`endif

    .jtag_tck           ( 1'b0              ),
    .jtag_tms           ( 1'b0              ),
    .jtag_tdi           ( 1'b0              ),
    .jtag_tdo           (                   ),

    .i2c_scl_in         ( i2c_scl_in        ),
    .i2c_scl_out        ( i2c_scl_out       ),
    .i2c_scl_oen        ( i2c_scl_oen       ),
    .i2c_sda_in         ( i2c_sda_in        ),
    .i2c_sda_out        ( i2c_sda_out       ),
    .i2c_sda_oen        ( i2c_sda_oen       ),
    
    .gpio_pu            ( gpio_pu           ),
    .gpio_pd            ( gpio_pd           ),
    .gpio_ie            ( gpio_ie           ),
    .gpio_in            ( gpio_in           ),
    .gpio_oe            ( gpio_oe           ),
    .gpio_out           ( gpio_out          )
);

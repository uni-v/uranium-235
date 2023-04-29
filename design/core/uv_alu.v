//************************************************************
// See LICENSE for license details.
//
// Module: uv_alu
//
// Designer: Owen
//
// Description:
//      Arithmetic Logic Unit.
//************************************************************

`timescale 1ns / 1ps

module uv_alu
#(
    parameter ALU_DW = 32,
    parameter SFT_DW = 5
)
(
    input                   clk,
    input                   rst_n,
    
    // If signed for shifter & adder
    input                   alu_sgn,
    // Shift
    input                   alu_sft,
    input                   alu_stl,
    // Arithmetic
    input                   alu_add,
    input                   alu_sub,
    input                   alu_lui,
    // Logical
    input                   alu_xor,
    input                   alu_or,
    input                   alu_and,
    // Compare
    input                   alu_slt,
    
    // ALU oprands
    input  [ALU_DW-1:0]     alu_opa,
    input  [ALU_DW-1:0]     alu_opb,
    output [ALU_DW-1:0]     alu_res,
    
    // CMP results
    output                  cmp_eq,
    output                  cmp_ne,
    output                  cmp_lt,
    output                  cmp_ge
);

    localparam UDLY         = 1;
    genvar i;
    
    // Shift-related wires
    wire [ALU_DW-1:0]       sft_opa;
    wire [ALU_DW-1:0]       sft_opb;
    wire [ALU_DW-1:0]       rev_opa;
    wire [ALU_DW-1:0]       sra_lbs;
    wire [ALU_DW-1:0]       sra_hbs;
    wire [ALU_DW-1:0]       sra_sgn;
    wire [ALU_DW-1:0]       sra_val;
    wire [ALU_DW-1:0]       sft_res;
    wire [ALU_DW-1:0]       sll_res;
    wire [ALU_DW-1:0]       srl_res;
    wire [ALU_DW-1:0]       sra_res;
    
    // Arithmetic-related wires
    wire                    add_sga;
    wire                    add_sgb;
    wire [ALU_DW:0]         add_exa;
    wire [ALU_DW:0]         add_exb;
    wire [ALU_DW:0]         add_opa;
    wire [ALU_DW:0]         add_opb;
    wire                    add_cin;
    wire [ALU_DW:0]         add_res;
    
    // Logic-related wires
    wire [ALU_DW-1:0]       xor_res;
    wire [ALU_DW-1:0]       or_res;
    wire [ALU_DW-1:0]       and_res;
    
    // Oprators
    assign sll_res = sft_opa << sft_opb;
    assign add_res = add_opa + add_opb + add_cin;
    assign xor_res = alu_opa ^ alu_opb;
    assign or_res  = alu_opa | alu_opb;
    assign and_res = alu_opa & alu_opb;
    
    // Get shift operands.
    generate
        for (i = 0; i < ALU_DW; i = i + 1) begin: gen_rev_opa
            assign rev_opa[i] = alu_opa[ALU_DW-i-1];
        end
    endgenerate
    
    //assign sft_opa = {ALU_DW{alu_sft}} & (alu_stl ? alu_opa : rev_opa);
    //assign sft_opb = {{(ALU_DW-SFT_DW){1'b0}}, {SFT_DW{alu_sft}} & alu_opb[SFT_DW-1:0]};
    assign sft_opa = alu_stl ? alu_opa : rev_opa;
    assign sft_opb = {{(ALU_DW-SFT_DW){1'b0}}, alu_opb[SFT_DW-1:0]};
    
    // Get shift results.
    generate
        for (i = 0; i < ALU_DW; i = i + 1) begin: gen_srl_res
            assign srl_res[i] = sll_res[ALU_DW-i-1];
        end
    endgenerate
    
    assign sra_lbs = {ALU_DW{1'b1}} >> alu_opb[SFT_DW-1:0];
    assign sra_hbs = ~sra_lbs;
    assign sra_sgn = {ALU_DW{alu_opa[ALU_DW-1]}} & sra_hbs;
    assign sra_val = srl_res & sra_lbs;
    assign sra_res = sra_sgn | sra_val;
    assign sft_res = alu_stl ? sll_res : (alu_sgn ? sra_res : srl_res);
    
    // Get add operands.
    assign add_sga = alu_sgn & alu_opa[ALU_DW-1];
    assign add_sgb = alu_sgn & alu_opb[ALU_DW-1];
    assign add_exa = {add_sga, alu_opa};
    assign add_exb = {add_sgb, alu_opb};
    assign add_opa = {(ALU_DW+1){alu_add}} & add_exa;
    assign add_opb = {(ALU_DW+1){alu_add}} & (alu_sub ? (~add_exb) : add_exb);
    assign add_cin = alu_sub;
    
    // Get ALU results.
    assign alu_res = ({ALU_DW{alu_sft}} & sft_res)
                   | ({ALU_DW{alu_xor}} & xor_res)
                   | ({ALU_DW{alu_or }} & or_res )
                   | ({ALU_DW{alu_and}} & and_res)
                   | ({ALU_DW{alu_lui}} & alu_opb)
                   | ({ALU_DW{alu_add & (~alu_slt)}} & add_res[ALU_DW-1:0])
                   | ({ALU_DW{alu_slt}} & {{(ALU_DW-1){1'b0}}, add_res[ALU_DW]});
    
    // Get cmp results.
    assign cmp_ne  = |xor_res;
    assign cmp_eq  = ~cmp_ne;
    assign cmp_lt  = add_res[ALU_DW];
    assign cmp_ge  = ~add_res[ALU_DW];
    
endmodule

//************************************************************
// See LICENSE for license details.
//
// Module: tb_mem
//
// Designer: Owen
//
// Description:
//      For memory data preloading.
//************************************************************

reg [MAX_STRING_LEN*8-1:0] inst_file;
reg [7:0]       inst_buf[0:INST_MEM_DEPTH*4-1];
integer         inst_idx;

initial begin
    for (inst_idx = 0; inst_idx < INST_MEM_DEPTH*4; inst_idx = inst_idx + 1) begin
        inst_buf[inst_idx] = {$random(seed)};
    end

    if ($value$plusargs("INST_FILE=%s", inst_file)) begin
        $readmemh(inst_file, inst_buf);
        for (inst_idx = 0; inst_idx < INST_MEM_DEPTH; inst_idx = inst_idx + 1) begin
            `INST_MEM[inst_idx] = {
                                    inst_buf[inst_idx*4+3],
                                    inst_buf[inst_idx*4+2],
                                    inst_buf[inst_idx*4+1],
                                    inst_buf[inst_idx*4+0]
                                };
        end
    end
    else begin
        $display("No instruction file!");
    end
end

task read_dam;
    input  [31:0]   addr;
    output [31:0]   data;
begin
    if (addr & 32'h80000000) begin
        if (addr[15:0] < 16'h8000) begin
            data = `INST_MEM[addr[15:0]];
        end
        else begin
            data = `DATA_MEM[addr[15:0] - 16'h8000];
        end
    end
    else begin
        $display("Fatal: Unexpected DAM reading address 0x%08h!", addr);
        SIM_END = 1'b1;
    end
end
endtask

task write_dam;
    input  [31:0]   addr;
    input  [31:0]   data;
begin
    if (addr & 32'h80000000) begin
        if (addr[15:0] < 16'h8000) begin
            `INST_MEM[addr[15:0]] = data;
        end
        else begin
            `DATA_MEM[addr[15:0] - 16'h8000] = data;
        end
    end
    else begin
        $display("Fatal: Unexpected DAM writing address 0x%08h!", addr);
        SIM_END = 1'b1;
    end
end
endtask

// See LICENSE for license details.

task tb_delay;
    input integer   cycles;
begin
    repeat(cycles) @(posedge clk);
end
endtask

task tb_low_delay;
    input integer   cycles;
begin
    repeat(cycles) @(posedge lck);
end
endtask

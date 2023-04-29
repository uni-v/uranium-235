# See LICENSE for license details.

import sys, os, platform

included_list = ['rv32mi-p-csr', 'rv32mi-p-mcsr']
excluded_list = ['rv32ui-p-fence_i', 'rv32ui-p-simple']

def test_isa(sti_name):
    testbench_path = '../testbench/tb_uv_sys'
    system = platform.system().lower()
    if system == 'windows':
        os.system('cd %s && .\\sim_riscv_tests.bat isa %s'
                    % (testbench_path, sti_name))
    else:
        os.system('cd %s && sh ./sim_riscv_tests.sh isa %s'
                    % (testbench_path, sti_name))

def regress_isa(simulator):
    global included_list
    global excluded_list
    stimulus_path = '../stimulus/riscv-tests/isa/build'
    
    data_files = os.listdir(stimulus_path)
    data_files.sort()
    for data_file in data_files:
        if data_file.endswith('.hex'):
            sti_name = data_file[:data_file.rfind('.hex')]
            # Exclude mi now.
            if sti_name.startswith('rv32mi-'):
                excluded_list.append(sti_name)
            if (sti_name in included_list) or (sti_name not in excluded_list):
                test_isa(sti_name)
                print("")

if __name__ == '__main__':
    simulator = 'iverilog'
    if len(sys.argv) > 1:
        simulator = sys.argv[1]
    regress_isa(simulator)

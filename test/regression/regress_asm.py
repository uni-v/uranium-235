# See LICENSE for license details.

import sys, os, platform

def regress_asm(simulator):
    stimulus_path = '../stimulus/build'
    testbench_path = '../testbench/tb_uv_sys'
    system = platform.system().lower()
    data_dirs = os.listdir(stimulus_path)
    data_dirs.sort()
    for data_dir in data_dirs:
        data_files = os.listdir(os.path.join(stimulus_path, data_dir))
        for data_file in data_files:
            if data_file.endswith('.hex'):
                sti_name = data_file[:data_file.rfind('.hex')]
                if system == 'windows':
                    os.system('cd %s && .\\sim_inst_seq.bat %s' % (testbench_path, sti_name))
                else:
                    os.system('cd %s && sh ./sim_inst_seq.sh %s' % (testbench_path, sti_name))

if __name__ == '__main__':
    simulator = 'iverilog'
    if len(sys.argv) > 1:
        simulator = sys.argv[1]
    regress_asm(simulator)

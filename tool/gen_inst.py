# See LICENSE for license details.

import sys, os

def gen_one_inst(asm_line):
    pass

def gen_inst(asm_file_name):
    hex_file_name = asm_file_name[:asm_file_name.rfind('.')] + '.hex'
    asm_file = open(asm_file_name, 'r')
    hex_file = open(hex_file_name, 'w')
    asm_lines = asm_file.readlines()
    for asm_line in asm_lines:
        asm_line = asm_line.strip()
        if len(asm_line) > 0:
            if asm_line[0] in ['#', ';'] or asm_line[0:2] == '//'
                pass
            else:
                asm_val = gen_one_inst(asm_line)
                hex_file.write('%08x\n' % asm_val)

if __name__ == '__main__':
    asm_file_name = 'test.asm'
    if len(sys.argv) > 0:
        asm_file_name = sys.argv[1]
    gen_inst_hex(asm_file_name)

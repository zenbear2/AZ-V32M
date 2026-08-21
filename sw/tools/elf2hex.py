#!/usr/bin/env python3
"""
File: elf2hex.py
Description: Converts raw binary image (.bin) to Verilog $readmemh byte hex format (.hex)
Project: AZ_V RISC-V CPU
"""

import sys
import argparse

def bin2hex(bin_filename, hex_filename, pad_bytes=0):
    with open(bin_filename, 'rb') as f:
        data = f.read()

    with open(hex_filename, 'w') as f:
        f.write(f"// AZ_V Memory Preload Hex generated from {bin_filename}\n")
        f.write(f"// Size: {len(data)} bytes\n")
        
        for i, byte in enumerate(data):
            f.write(f"{byte:02x}\n")
            
        if pad_bytes > len(data):
            for _ in range(len(data), pad_bytes):
                f.write("00\n")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Convert binary file to SystemVerilog byte $readmemh format')
    parser.add_argument('bin', help='Input binary file (.bin)')
    parser.add_argument('hex', help='Output hex file (.hex)')
    parser.add_argument('--pad', type=int, default=0, help='Pad total output to N bytes')
    
    args = parser.parse_args()
    bin2hex(args.bin, args.hex, args.pad)
    print(f"[elf2hex.py] Successfully generated {args.hex} from {args.bin}")

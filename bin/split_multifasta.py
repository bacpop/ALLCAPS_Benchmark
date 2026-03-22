#!/usr/bin/env python3
"""Split a multi-FASTA file into per-sample single-contig FASTA files.

Usage: split_multifasta.py <input.fasta> <output_dir/>

Output files are named <record_id>.fasta inside output_dir.
"""
import os
import sys


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.fasta> <output_dir>", file=sys.stderr)
        sys.exit(1)

    input_fasta = sys.argv[1]
    output_dir = sys.argv[2]
    os.makedirs(output_dir, exist_ok=True)

    current_id = None
    current_lines = []

    def flush():
        if current_id and current_lines:
            # Sanitize filename (replace problematic characters)
            safe_id = current_id.replace("/", "_").replace("\\", "_")
            out_path = os.path.join(output_dir, f"{safe_id}.fasta")
            with open(out_path, "w") as out_f:
                out_f.writelines(current_lines)

    with open(input_fasta) as f:
        for line in f:
            if line.startswith(">"):
                flush()
                current_id = line[1:].split()[0].strip()
                current_lines = [line]
            else:
                current_lines.append(line)
    flush()


if __name__ == "__main__":
    main()

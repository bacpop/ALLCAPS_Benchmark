#!/usr/bin/env python3
"""Parse PfaSTer output directory into standardized CSV format.

PfaSTer writes results to an output directory. The exact output format
depends on the version; this parser tries multiple strategies.

Usage: parse_pfaster.py <sample_id> <output_dir>
Outputs to stdout: sample_id,tool,predicted_serotype
"""
import csv
import os
import sys


def parse_pfaster(sample_id: str, output_dir: str) -> str:
    serotype = "FAILED"

    result_file = os.path.join(output_dir, "prediction.txt")
    if os.path.exists(result_file):
        with open(result_file) as f:
            lines = [ln.strip() for ln in f]
        if len(lines) >= 2 and lines[1]:
            if lines[1] not in ["not typed", "NA"]:
                serotype = lines[1]

    return serotype


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <sample_id> <output_dir>", file=sys.stderr)
        sys.exit(1)

    sample_id = sys.argv[1]
    output_dir = sys.argv[2]
    serotype = parse_pfaster(sample_id, output_dir)

    writer = csv.writer(sys.stdout)
    writer.writerow(["sample_id", "tool", "predicted_serotype"])
    writer.writerow([sample_id, "PfaSTer", serotype])


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Parse PfaSTer output directory into standardized CSV format.

PfaSTer writes results to an output directory. The exact output format
depends on the version; this parser tries multiple strategies.

Usage: parse_pfaster.py <sample_id> <output_dir>
Outputs to stdout: sample_id,tool,predicted_serotype
"""
import csv
import glob
import os
import sys


def parse_pfaster(sample_id: str, output_dir: str) -> str:
    serotype = "FAILED"

    # Strategy 1: look for CSV/TSV files in output dir
    for pattern in ("*.csv", "*.tsv", "*.txt"):
        for fpath in glob.glob(os.path.join(output_dir, pattern)):
            with open(fpath) as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    # Try to find serotype in the line
                    if "Serotype" in line and ":" in line:
                        serotype = line.split(":")[-1].strip()
                        return serotype
                    # Try CSV parse: assume first column after header
                    parts = line.split(",")
                    if len(parts) >= 2 and parts[0].strip().lower() != "serotype":
                        serotype = parts[0].strip()
                        return serotype

    # Strategy 2: look for console-style output captured to file
    result_file = os.path.join(output_dir, "result.txt")
    if os.path.exists(result_file):
        with open(result_file) as f:
            for line in f:
                if "Serotype" in line:
                    serotype = line.split(":")[-1].strip()
                    return serotype

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

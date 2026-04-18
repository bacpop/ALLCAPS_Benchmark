#!/usr/bin/env python3
"""Parse SeroBA pred.csv output into standardized CSV format.

Usage: parse_seroba.py <sample_id> <pred.csv>
Outputs to stdout: sample_id,tool,predicted_serotype
"""
import csv
import sys


def parse_seroba(sample_id: str, pred_csv: str) -> str:
    serotype = "FAILED"
    with open(pred_csv) as f:
        line = f.readlines()[-1].strip()  # Read the last line of the file
        # SeroBA v2 pred.csv format: comma-separated, second field is serotype: "Sample,Serotype,Genetic_Variant,Contamination_Status"
        parts = line.split(",")
        if len(parts) > 1:
            serotype = parts[1].strip()
        else:
            print(f"Warning: Unexpected format in {pred_csv}. Expected at least 2 fields, got: {line}", file=sys.stderr)

    return serotype


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <sample_id> <pred.csv>", file=sys.stderr)
        sys.exit(1)

    sample_id = sys.argv[1]
    pred_csv = sys.argv[2]
    serotype = parse_seroba(sample_id, pred_csv)

    writer = csv.writer(sys.stdout)
    writer.writerow(["sample_id", "tool", "predicted_serotype"])
    writer.writerow([sample_id, "SeroBA", serotype])


if __name__ == "__main__":
    main()

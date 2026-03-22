#!/usr/bin/env python3
"""Parse SeroBA pred.tsv output into standardized CSV format.

Usage: parse_seroba.py <sample_id> <pred.tsv>
Outputs to stdout: sample_id,tool,predicted_serotype
"""
import csv
import sys


def parse_seroba(sample_id: str, pred_tsv: str) -> str:
    serotype = "FAILED"
    with open(pred_tsv) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            # SeroBA v2 pred.tsv format: tab-separated, first field is serotype
            # or "Predicted Serotype:\t<serotype>"
            if "Predicted Serotype" in line:
                parts = line.split("\t")
                if len(parts) >= 2:
                    serotype = parts[-1].strip()
                    break
            else:
                # Fallback: first column is serotype
                parts = line.split("\t")
                serotype = parts[0].strip()
                break
    return serotype


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <sample_id> <pred.tsv>", file=sys.stderr)
        sys.exit(1)

    sample_id = sys.argv[1]
    pred_tsv = sys.argv[2]
    serotype = parse_seroba(sample_id, pred_tsv)

    writer = csv.writer(sys.stdout)
    writer.writerow(["sample_id", "tool", "predicted_serotype"])
    writer.writerow([sample_id, "SeroBA", serotype])


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Parse TriHead merged_query_results.csv into standardized CSV format.

Usage: parse_trihead.py <merged_query_results.csv>
Outputs to stdout: sample_id,tool,predicted_serotype
"""
import csv
import sys


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <merged_query_results.csv>", file=sys.stderr)
        sys.exit(1)

    merged_csv = sys.argv[1]
    writer = csv.writer(sys.stdout)
    writer.writerow(["sample_id", "tool", "predicted_serotype"])

    with open(merged_csv) as f:
        reader = csv.DictReader(f)
        for row in reader:
            # Identify sample_id from record_id or first column
            sample_id = row.get("record_id", row.get("sample_id", ""))
            # Prediction column
            pred = row.get("pred_serotype", row.get("pred_argmax", ""))
            if sample_id and pred:
                writer.writerow([sample_id, "TriHead", pred])


if __name__ == "__main__":
    main()

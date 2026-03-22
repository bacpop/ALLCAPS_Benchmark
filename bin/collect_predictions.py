#!/usr/bin/env python3
"""Collect per-tool parsed CSVs into a single unified predictions file.

Usage: collect_predictions.py file1.csv file2.csv ... > all_predictions.csv
Each input CSV has header: sample_id,tool,predicted_serotype
"""
import csv
import sys


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <csv_files...>", file=sys.stderr)
        sys.exit(1)

    writer = csv.writer(sys.stdout)
    writer.writerow(["sample_id", "tool", "predicted_serotype"])

    for fpath in sys.argv[1:]:
        with open(fpath) as f:
            reader = csv.DictReader(f)
            for row in reader:
                writer.writerow([
                    row["sample_id"],
                    row["tool"],
                    row["predicted_serotype"],
                ])


if __name__ == "__main__":
    main()

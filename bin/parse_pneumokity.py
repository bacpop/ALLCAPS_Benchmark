#!/usr/bin/env python3
"""Parse PneumoKITy result_data.csv into standardized CSV format.

Usage: parse_pneumokity.py <sample_id> <result_data.csv>
Outputs to stdout: sample_id,tool,predicted_serotype
"""
import csv
import sys


def parse_pneumokity(sample_id: str, result_csv: str) -> str:
    serotype = "FAILED"
    with open(result_csv) as f:
        reader = csv.DictReader(f)
        for row in reader:
            # PneumoKITy result_data.csv has "predicted serotype" column
            for key in ("predicted serotype", "Predicted serotype", "predicted_serotype"):
                if key in row:
                    val = row[key].strip()
                    if val:
                        serotype = val
                    break
            break  # only one row per sample
    return serotype


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <sample_id> <result_data.csv>", file=sys.stderr)
        sys.exit(1)

    sample_id = sys.argv[1]
    result_csv = sys.argv[2]
    serotype = parse_pneumokity(sample_id, result_csv)

    writer = csv.writer(sys.stdout)
    writer.writerow(["sample_id", "tool", "predicted_serotype"])
    writer.writerow([sample_id, "PneumoKITy", serotype])


if __name__ == "__main__":
    main()

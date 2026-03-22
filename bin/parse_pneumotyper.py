#!/usr/bin/env python3
"""Parse Pneumo-Typer Serotype.out into standardized CSV format.

Usage: parse_pneumotyper.py <Serotype.out>
Outputs to stdout: sample_id,tool,predicted_serotype
"""
import csv
import sys


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <Serotype.out>", file=sys.stderr)
        sys.exit(1)

    serotype_out = sys.argv[1]
    writer = csv.writer(sys.stdout)
    writer.writerow(["sample_id", "tool", "predicted_serotype"])

    with open(serotype_out) as f:
        reader = csv.reader(f, delimiter="\t")
        header = next(reader, None)
        if header is None:
            return

        # Find column indices
        strain_idx = 0
        sero_idx = 1
        for i, col in enumerate(header):
            col_lower = col.strip().lower()
            if col_lower in ("strain", "genome", "sample"):
                strain_idx = i
            elif col_lower == "serotype":
                sero_idx = i

        for row in reader:
            if len(row) > max(strain_idx, sero_idx):
                sample_id = row[strain_idx].strip()
                serotype = row[sero_idx].strip()
                # Strip file extensions from strain name
                for ext in (".fasta", ".fa", ".fna", ".gbk", ".gb"):
                    if sample_id.endswith(ext):
                        sample_id = sample_id[: -len(ext)]
                writer.writerow([sample_id, "Pneumo-Typer", serotype])


if __name__ == "__main__":
    main()

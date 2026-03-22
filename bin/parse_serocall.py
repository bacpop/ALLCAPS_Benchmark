#!/usr/bin/env python3
"""Parse SeroCall *_calls.txt into standardized CSV format.

Usage: parse_serocall.py <sample_id> <calls.txt>
Outputs to stdout: sample_id,tool,predicted_serotype
"""
import csv
import sys


def parse_serocall(sample_id: str, calls_txt: str) -> str:
    """Extract the top serotype from SeroCall output.

    SeroCall _calls.txt has header lines starting with ## or #SEROTYPE,
    then tab-separated lines: SEROTYPE\tPERCENTAGE.
    Return the first (highest abundance) serotype.
    """
    serotype = "FAILED"
    with open(calls_txt) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("##") or line.startswith("#SEROTYPE"):
                continue
            parts = line.split("\t")
            if parts:
                serotype = parts[0].strip()
                break
    return serotype


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <sample_id> <calls.txt>", file=sys.stderr)
        sys.exit(1)

    sample_id = sys.argv[1]
    calls_txt = sys.argv[2]
    serotype = parse_serocall(sample_id, calls_txt)

    writer = csv.writer(sys.stdout)
    writer.writerow(["sample_id", "tool", "predicted_serotype"])
    writer.writerow([sample_id, "SeroCall", serotype])


if __name__ == "__main__":
    main()

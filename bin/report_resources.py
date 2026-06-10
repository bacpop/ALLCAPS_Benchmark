#!/usr/bin/env python3
"""Average wall-clock time and peak RSS per query for each tool subdir, from Nextflow traces.

Works for both layouts:
  - one task per sample (PFASTER_SINGLE, SEROBA_SINGLE, ...) -> mean realtime
  - one batch task for all samples (PNEUMOKITY_BATCH, PNEUMOTYPER) -> realtime / N
By summing the realtime of the "work" tasks and dividing by the number of
queries (rows in predictions/all_predictions.csv), both cases collapse to the
same formula.
"""
import csv
import re
import sys
from pathlib import Path

AUX = ("COLLECT_PREDICTIONS", "BUILD_REPORT", "PARSE")  # not real per-query work

_UNIT = {"ms": 1e-3, "s": 1, "m": 60, "h": 3600, "d": 86400}
_BYTES = {"B": 1, "KB": 1e3, "MB": 1e6, "GB": 1e9, "TB": 1e12}


def to_seconds(s):
    """Parse a Nextflow duration like '8h 35m 21s', '33.8s', '76ms', '-'."""
    s = s.strip()
    if not s or s == "-":
        return 0.0
    total = 0.0
    for num, unit in re.findall(r"([\d.]+)\s*(ms|[dhms])", s):
        total += float(num) * _UNIT[unit]
    return total


def to_mb(s):
    """Parse a Nextflow size like '94 MB', '1.5 GB', '-' into MB."""
    s = s.strip()
    if not s or s == "-":
        return 0.0
    m = re.match(r"([\d.]+)\s*([KMGT]?B)", s)
    return float(m.group(1)) * _BYTES[m.group(2)] / 1e6 if m else 0.0


def query_count(tool_dir):
    csv_path = tool_dir / "predictions" / "all_predictions.csv"
    with open(csv_path) as fh:
        return sum(1 for _ in fh) - 1  # minus header


def main():
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    print(f"{'tool':<14}{'queries':>9}{'work_s':>14}{'sec/query':>12}{'peak_rss_MB':>14}")
    for tool_dir in sorted(p for p in root.iterdir() if (p / "trace.txt").exists()):
        n = query_count(tool_dir)
        work_seconds = 0.0
        rss = []
        with open(tool_dir / "trace.txt") as fh:
            for row in csv.DictReader(fh, delimiter="\t"):
                name = row["name"].split(" (")[0]
                if any(a in name for a in AUX):
                    continue
                work_seconds += to_seconds(row["realtime"])
                rss.append(to_mb(row["peak_rss"]))
        per_query = work_seconds / n if n else float("nan")
        mean_rss = sum(rss) / len(rss) if rss else float("nan")
        print(f"{tool_dir.name:<14}{n:>9}{work_seconds:>14.1f}{per_query:>12.3f}{mean_rss:>14.1f}")


if __name__ == "__main__":
    main()

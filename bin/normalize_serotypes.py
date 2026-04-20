#!/usr/bin/env python3
"""Normalize and filter serotype predictions and true labels.

Called as a preprocessing step inside BUILD_REPORT, before build_confusion_matrix.py.
Applied uniformly to all tools.

Prediction normalizations (string aliases):
  Serogroup_6_(6E)        → 6E   (specific enough to credit as a serotype call)

Prediction filters (rows excluded from benchmarking entirely):
  "Below 70% hit ..."     — low-quality / non-typeable signal
  "Mixed serotypes- ..."  — tool could not resolve to a single serotype
  "Serogroup NN"          — coarse serogroup call; crediting a serotype prediction
                            against a serogroup true label is handled separately in
                            build_confusion_matrix.py via SEROGROUP_MEMBERS

True-label normalizations (notation variants for the same serotype):
  15B/C                   → 15B/15C

Outputs:
  predictions_normalized.csv   same columns as input, filtered/renamed
  labels_normalized.csv        same columns as input, notation unified
  normalization_log.tsv        every change/filter applied
"""

import argparse
import re
import sys

import pandas as pd

# ── Prediction string aliases ─────────────────────────────────────────────────
# Serogroup_6_(6E) is PneumoKITy's label for 6E specifically — credit it.
PREDICTION_ALIASES = {
    "Serogroup_6_(6E)": "6E",
}

# ── Invalid prediction patterns ───────────────────────────────────────────────
# Predictions matching any of these are dropped entirely (not counted as FN or FP).
INVALID_PREDICTION_PATTERNS = [
    re.compile(r"^Below 70%", re.IGNORECASE),
    re.compile(r"^Mixed serotypes", re.IGNORECASE),
    re.compile(r"^Serogroup \d+$", re.IGNORECASE),          # Serogroup 24, Serogroup 33, ...
    # SeroBA compound-group outputs — tool could not resolve to a single serotype
    re.compile(r"^11A/11B/11C/11D/11E/11F/11F_like$"),
    re.compile(r"^24B/24C/24F$"),
    re.compile(r"^33A/33E/33F$"),
]

# ── Invalid true-label patterns ───────────────────────────────────────────────
# Samples whose ground-truth label matches any of these are excluded entirely.
INVALID_TRUE_LABEL_PATTERNS = [
    re.compile(r"\?"),         # ambiguous annotations (e.g. 35A/42?)
    re.compile(r"^NCC2_"),     # non-encapsulated strains — not a serotyping target
]

# ── True-label string aliases ─────────────────────────────────────────────────
# Different metadata sources / databases use alternative notation for the same
# serotype. Standardise to the form PneumoKITy (and GPS) uses.
TRUE_LABEL_ALIASES = {
    "15B/C": "15B/15C",
    # Add further entries here as new notation mismatches are discovered.
}


def is_invalid_prediction(pred: str) -> bool:
    return any(p.search(str(pred)) for p in INVALID_PREDICTION_PATTERNS)


def is_invalid_true_label(label: str) -> bool:
    return any(p.search(str(label)) for p in INVALID_TRUE_LABEL_PATTERNS)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--predictions", required=True,
                        help="all_predictions.csv (sample_id,tool,predicted_serotype)")
    parser.add_argument("--labels", required=True,
                        help="Ground-truth labels CSV (must contain Public_ID and Serotype columns)")
    parser.add_argument("--out_predictions", default="predictions_normalized.csv",
                        help="Output path for normalized predictions")
    parser.add_argument("--out_labels", default="labels_normalized.csv",
                        help="Output path for normalized true labels")
    parser.add_argument("--out_log", default="normalization_log.tsv",
                        help="Output path for normalization log")
    args = parser.parse_args()

    preds  = pd.read_csv(args.predictions)
    labels = pd.read_csv(args.labels)

    log_rows = []

    # ── 1. Rename messy prediction strings to canonical serotypes ────────────
    for raw, canonical in PREDICTION_ALIASES.items():
        mask = preds["predicted_serotype"] == raw
        n = int(mask.sum())
        if n:
            preds.loc[mask, "predicted_serotype"] = canonical
            log_rows.append({
                "step": "prediction_alias",
                "original": raw,
                "normalized": canonical,
                "n_rows": n,
                "note": "renamed to canonical serotype string",
            })
            print(f"[normalize] prediction alias: '{raw}' → '{canonical}' ({n} rows)",
                  file=sys.stderr)

    # ── 2. Drop invalid predictions ──────────────────────────────────────────
    invalid_mask = preds["predicted_serotype"].apply(is_invalid_prediction)
    n_invalid = int(invalid_mask.sum())
    if n_invalid:
        for pred_val, grp in preds[invalid_mask].groupby("predicted_serotype"):
            log_rows.append({
                "step": "prediction_filtered",
                "original": pred_val,
                "normalized": "EXCLUDED",
                "n_rows": len(grp),
                "note": "below-70%, mixed serotype, or coarse serogroup — excluded from benchmark",
            })
        print(f"[normalize] filtered {n_invalid} invalid predictions "
              f"(Below70% / Mixed / Serogroup NN)", file=sys.stderr)
        preds = preds[~invalid_mask].copy()

    # ── 3. Normalise true-label notation ─────────────────────────────────────
    for raw, canonical in TRUE_LABEL_ALIASES.items():
        mask = labels["Serotype"] == raw
        n = int(mask.sum())
        if n:
            labels.loc[mask, "Serotype"] = canonical
            log_rows.append({
                "step": "true_label_alias",
                "original": raw,
                "normalized": canonical,
                "n_rows": n,
                "note": "alternative notation for the same serotype",
            })
            print(f"[normalize] true-label alias: '{raw}' → '{canonical}' ({n} samples)",
                  file=sys.stderr)

    # ── 4. Drop invalid true labels ──────────────────────────────────────────
    invalid_label_mask = labels["Serotype"].apply(is_invalid_true_label)
    n_invalid_labels = int(invalid_label_mask.sum())
    if n_invalid_labels:
        for label_val, grp in labels[invalid_label_mask].groupby("Serotype"):
            log_rows.append({
                "step": "true_label_filtered",
                "original": label_val,
                "normalized": "EXCLUDED",
                "n_rows": len(grp),
                "note": "ambiguous annotation (?) or non-encapsulated strain (NCC2) — excluded from benchmark",
            })
        print(f"[normalize] filtered {n_invalid_labels} samples with invalid true labels "
              f"(ambiguous / NCC2)", file=sys.stderr)
        labels = labels[~invalid_label_mask].copy()

    # ── Write outputs ─────────────────────────────────────────────────────────
    preds.to_csv(args.out_predictions, index=False)
    labels.to_csv(args.out_labels, index=False)

    log_df = pd.DataFrame(
        log_rows,
        columns=["step", "original", "normalized", "n_rows", "note"],
    )
    log_df.to_csv(args.out_log, sep="\t", index=False)

    total_changes = sum(r["n_rows"] for r in log_rows)
    print(f"[normalize] done — {total_changes} rows/samples affected; "
          f"log → {args.out_log}", file=sys.stderr)


if __name__ == "__main__":
    main()

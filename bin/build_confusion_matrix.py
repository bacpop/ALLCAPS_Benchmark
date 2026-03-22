#!/usr/bin/env python3
"""Build per-tool confusion matrices and a cross-tool summary from unified predictions.

Usage:
    build_confusion_matrix.py \\
        --predictions all_predictions.csv \\
        --labels labels.csv \\
        --outdir output/

Inputs:
    all_predictions.csv: sample_id, tool, predicted_serotype
    labels.csv:          Public_ID, Contig_ID, Serotype, Is_capsule

Outputs (per tool):
    <tool>_confusion_matrix.csv
    <tool>_report.txt
    <tool>_confusion_matrix.pdf  (if matplotlib available)

Aggregated:
    benchmark_summary.tsv
"""

import argparse
import os
import sys

import numpy as np
import pandas as pd
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
)

# ── Serotype normalization ────────────────────────────────────
# Different tools use different naming conventions. This mapping
# normalizes common variants to a canonical form.
SEROTYPE_ALIASES = {
    # Zero-padded → unpadded
    "01": "1",
    "02": "2",
    "03": "3",
    "04": "4",
    "05": "5",
    "07A": "7A",
    "07B": "7B",
    "07C": "7C",
    "07F": "7F",
    "08": "8",
    "09A": "9A",
    "09L": "9L",
    "09N": "9N",
    "09V": "9V",
    # Failure modes → unified label
    "untypable": "NT",
    "Untypable": "NT",
    "UNTYPABLE": "NT",
    "Non-typeable": "NT",
    "non-typeable": "NT",
    "Failed": "FAILED",
    "failed": "FAILED",
    "FAILED": "FAILED",
    "No hits": "FAILED",
    # Common SeroBA outputs
    "": "FAILED",
}


def normalize_serotype(s: str) -> str:
    """Normalize a serotype string to canonical form."""
    s = str(s).strip()
    return SEROTYPE_ALIASES.get(s, s)


def make_confusion_plot(cm_df: pd.DataFrame, tool: str, outdir: str):
    """Generate a confusion matrix heatmap if matplotlib is available."""
    try:
        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        import seaborn as sns
    except ImportError:
        return

    n_classes = len(cm_df)
    figsize = max(8, n_classes * 0.3)
    fig, ax = plt.subplots(figsize=(figsize, figsize))

    sns.heatmap(
        cm_df,
        annot=n_classes <= 40,
        fmt="d" if n_classes <= 40 else "",
        cmap="Blues",
        ax=ax,
        xticklabels=True,
        yticklabels=True,
        cbar_kws={"shrink": 0.6},
    )
    ax.set_xlabel("Predicted")
    ax.set_ylabel("True")
    ax.set_title(f"{tool} — Confusion Matrix")
    plt.tight_layout()
    plt.savefig(os.path.join(outdir, f"{tool}_confusion_matrix.pdf"), dpi=150)
    plt.close()


def evaluate_tool(
    df_tool: pd.DataFrame,
    tool: str,
    outdir: str,
) -> dict:
    """Evaluate a single tool's predictions vs. ground truth."""
    y_true = df_tool["true_serotype"].to_numpy()
    y_pred = df_tool["predicted_serotype"].to_numpy()
    labels = np.array(sorted(set(y_true) | set(y_pred)))

    acc = accuracy_score(y_true, y_pred)
    f1w = f1_score(y_true, y_pred, average="weighted", zero_division=0)
    f1m = f1_score(y_true, y_pred, average="macro", zero_division=0)

    clf_report = classification_report(
        y_true, y_pred, labels=labels, target_names=labels, zero_division=0
    )

    cm = confusion_matrix(y_true, y_pred, labels=labels)
    cm_df = pd.DataFrame(cm, index=labels, columns=labels)
    cm_df.to_csv(os.path.join(outdir, f"{tool}_confusion_matrix.csv"))

    # Write text report
    report_path = os.path.join(outdir, f"{tool}_report.txt")
    with open(report_path, "w") as f:
        f.write(f"{tool} — Serotype Classification Report\n")
        f.write("=" * 60 + "\n\n")
        f.write(f"Samples evaluated: {len(y_true)}\n")
        f.write(f"Unique classes:    {len(labels)}\n")
        f.write(f"Accuracy:          {acc:.4f}\n")
        f.write(f"F1 (weighted):     {f1w:.4f}\n")
        f.write(f"F1 (macro):        {f1m:.4f}\n\n")
        f.write("Classification Report:\n")
        f.write(clf_report)

    # Optional plot
    make_confusion_plot(cm_df, tool, outdir)

    return {
        "tool": tool,
        "n_samples": len(y_true),
        "n_classes": len(labels),
        "accuracy": round(acc, 4),
        "f1_weighted": round(f1w, 4),
        "f1_macro": round(f1m, 4),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--predictions", required=True, help="Unified predictions CSV")
    parser.add_argument("--labels", required=True, help="Ground-truth labels CSV")
    parser.add_argument("--outdir", default=".", help="Output directory")
    args = parser.parse_args()

    os.makedirs(args.outdir, exist_ok=True)

    # Load data
    preds = pd.read_csv(args.predictions)
    labels = pd.read_csv(args.labels)

    # Normalize serotype names
    preds["predicted_serotype"] = preds["predicted_serotype"].apply(normalize_serotype)
    labels["Serotype"] = labels["Serotype"].apply(normalize_serotype)

    # Join on sample_id == Public_ID
    merged = preds.merge(
        labels[["Public_ID", "Serotype"]].rename(
            columns={"Public_ID": "sample_id", "Serotype": "true_serotype"}
        ),
        on="sample_id",
        how="inner",
    )

    if merged.empty:
        print("WARNING: No matching samples between predictions and labels.", file=sys.stderr)
        # Still create empty summary
        pd.DataFrame(columns=["tool", "n_samples", "n_classes", "accuracy", "f1_weighted", "f1_macro"]).to_csv(
            os.path.join(args.outdir, "benchmark_summary.tsv"), sep="\t", index=False
        )
        return

    # Filter out FAILED predictions for metrics (but report count)
    failed_mask = merged["predicted_serotype"].isin(["FAILED", "NT", ""])
    n_failed = failed_mask.sum()
    if n_failed > 0:
        print(f"Note: {n_failed} predictions are FAILED/NT and will be included in evaluation.", file=sys.stderr)

    # Evaluate each tool
    tools = sorted(merged["tool"].unique())
    summary_rows = []

    for tool in tools:
        df_tool = merged[merged["tool"] == tool].copy()
        if df_tool.empty:
            continue
        row = evaluate_tool(df_tool, tool, args.outdir)
        summary_rows.append(row)
        print(f"{tool}: accuracy={row['accuracy']}, F1w={row['f1_weighted']}, F1m={row['f1_macro']}")

    # Write summary
    summary_df = pd.DataFrame(summary_rows)
    summary_path = os.path.join(args.outdir, "benchmark_summary.tsv")
    summary_df.to_csv(summary_path, sep="\t", index=False)
    print(f"\nSummary written to: {summary_path}")


if __name__ == "__main__":
    main()

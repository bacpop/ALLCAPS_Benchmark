# Pneumococcal Serotyping Benchmark

Nextflow pipeline to benchmark multiple *S. pneumoniae* in-silico serotyping tools against a common test set, producing per-tool confusion matrices and a cross-tool comparison report.

## Tools

| Tool | Input | Execution |
|------|-------|-----------|
| **AllCaps** (ours) | FASTA (contigs) | Conda (`ebi_env`) |
| **SeroBA v2** | Paired FASTQ | Singularity (`sangerbentleygroup/seroba`) |
| **PneumoKITy** | FASTA (assembly) | Conda env |
| **PfaSTer** | FASTA | Conda env |
| **PneumoCaT** | Paired FASTQ | Bioconda (PneumoCaT) |
| **SeroCall** | Paired FASTQ | Clone + Conda (BWA) |
| **Pneumo-Typer** | FASTA (assembly) | Clone + Conda (Perl/BLAST) |

## Quick Start

### 1. Clone external tools

```bash
mkdir -p tools/
git clone https://github.com/CarmenSheppard/PneumoKITy.git tools/PneumoKITy
git clone https://github.com/pfizer-opensource/pfaster.git  tools/pfaster
git clone https://github.com/knightjimr/SeroCall.git        tools/SeroCall
git clone https://github.com/Xiangyang1984/Pneumo-Typer.git tools/Pneumo-Typer
```

> **Note:** The pipeline runs Pneumo-Typer with `-m F` (serotype only, MLST/cgMLST
> skipped), so the large cgMLST datasets the upstream README mentions for the
> git-clone install are **not** required.

### 2. Pull Singularity image (for SeroBA)

```bash
singularity pull --dir singularity-cache docker://sangerbentleygroup/seroba
```

### 3. Prepare samplesheet

Create a CSV file (`samplesheet.csv`) with columns:

```
sample_id,fasta,fastq_1,fastq_2
ERR123456,/path/to/ERR123456.fasta,/path/to/ERR123456_1.fastq.gz,/path/to/ERR123456_2.fastq.gz
```

- `fasta` can be empty if only FASTQ is available (FASTA-only tools will be skipped for that sample)
- `fastq_1`/`fastq_2` can be empty if only FASTA is available (FASTQ-only tools will be skipped)

### 4. Prepare labels

Ground-truth CSV with columns:
```
Public_ID,Contig_ID,Serotype,Is_capsule
```

### 5. Run

```bash
# Local (testing)
nextflow run main.nf \
    --input samplesheet.csv \
    --labels labels.csv \
    --outdir results/

# SLURM cluster
nextflow run main.nf \
    -profile slurm \
    --input samplesheet.csv \
    --labels labels.csv \
    --outdir results/

# Include our AllCaps tool
nextflow run main.nf \
    -profile slurm \
    --input samplesheet.csv \
    --labels labels.csv \
    --allcaps_model /path/to/transformer_model.pth \
    --allcaps_repo  /path/to/pneumococcal-serotyping \
    --outdir results/

# Stub / dry run (no tools executed, tests pipeline logic)
nextflow run main.nf -stub \
    --input samplesheet.csv \
    --labels labels.csv
```

### 6. Skip specific tools

```bash
nextflow run main.nf \
    --input samplesheet.csv \
    --labels labels.csv \
    --run_seroba false \
    --run_allcaps false
```

## Multi-FASTA splitting

If your test data is a single multi-FASTA file, you can use the `--multifasta` option to automatically split it into per-sample FASTA files:

```bash
nextflow run main.nf \
    --input samplesheet.csv \
    --multifasta test.fasta \
    --labels labels.csv
```

## Output

```
results/
├── predictions/
│   └── all_predictions.csv          # Unified: sample_id, tool, predicted_serotype
├── report/
│   ├── benchmark_summary.csv        # Cross-tool comparison table
│   ├── SeroBA_confusion_matrix.csv
│   ├── SeroBA_report.txt
│   ├── SeroBA_confusion_matrix.pdf
│   ├── PneumoKITy_confusion_matrix.csv
│   ├── PneumoKITy_report.txt
│   ├── PfaSTer_confusion_matrix.csv
│   ├── PfaSTer_report.txt
│   ├── AllCaps_confusion_matrix.csv
│   └── AllCaps_report.txt
├── pipeline_report.html
├── timeline.html
└── trace.txt
```

## Adding a New Tool

1. Create `modules/newtool.nf` with a process that runs the tool and a `_PARSE` process
2. Create `bin/parse_newtool.py` that outputs `sample_id,tool,predicted_serotype` to stdout
3. Add the process to `main.nf` workflow (follow the pattern of existing tools)
4. Add a `params.run_newtool = false` toggle to `nextflow.config`

## Directory Structure

```
serotype-benchmark/
├── main.nf                  # Main workflow
├── nextflow.config          # Pipeline configuration
├── conf/
│   └── slurm.config         # SLURM executor settings
├── modules/
│   ├── seroba.nf            # SeroBA v2
│   ├── pneumokity.nf        # PneumoKITy
│   ├── pfaster.nf           # PfaSTer
│   ├── allcaps.nf           # AllCaps (our tool)
│   ├── pneumocat.nf         # PneumoCaT
│   ├── serocall.nf          # SeroCall
│   └── pneumotyper.nf       # Pneumo-Typer
├── bin/                     # Scripts (auto-added to PATH by Nextflow)
│   ├── parse_seroba.py
│   ├── parse_pneumokity.py
│   ├── parse_pfaster.py
│   ├── parse_allcaps.py
│   ├── parse_pneumocat.py
│   ├── parse_serocall.py
│   ├── parse_pneumotyper.py
│   ├── collect_predictions.py
│   ├── split_multifasta.py
│   └── build_confusion_matrix.py
├── envs/                    # Conda environment files
│   ├── pneumokity.yml
│   ├── pfaster.yml
│   ├── serocall.yml
│   └── pneumotyper.yml
├── assets/
│   └── samplesheet.csv      # Template samplesheet
└── tools/                   # Clone external tools here (gitignored)
    ├── PneumoKITy/
    └── pfaster/
```

## Serotype Label Normalization

Different tools use different naming conventions (e.g., `01` vs `1`, `untypable` vs `NT`). The `build_confusion_matrix.py` script normalizes these before computing metrics. Edit the `SEROTYPE_ALIASES` dict in that file to add more mappings.

## Requirements

- Nextflow >= 23.04
- Singularity / Apptainer (for SeroBA container)
- Conda / Micromamba (for PneumoKITy, PfaSTer)
- Python 3.7+ with: pandas, numpy, scikit-learn, matplotlib and seaborn (optional, for plots)

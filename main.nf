#!/usr/bin/env nextflow

/*
 * ══════════════════════════════════════════════════════════════
 *  Pneumococcal Serotyping Benchmark Pipeline
 * ══════════════════════════════════════════════════════════════
 *
 *  Compare SeroBA v2, PneumoKITy, PfaSTer, AllCaps, and
 *  (placeholder) PneumoCaT, SeroCall, Pneumo-Typer against a
 *  common test set.  Produces per-tool confusion matrices and
 *  a cross-tool comparison report.
 *
 *  Usage:
 *    nextflow run main.nf \
 *      --input  samplesheet.csv \
 *      --labels labels.csv      \
 *      --outdir results/
 *
 *  Stub / dry-run:
 *    nextflow run main.nf -stub --input samplesheet.csv --labels labels.csv
 */

nextflow.enable.dsl = 2

// ── Module imports ────────────────────────────────────────────
include { SEROBA;           SEROBA_PARSE           } from './modules/seroba'
include { PNEUMOKITY;       PNEUMOKITY_PARSE       } from './modules/pneumokity'
include { PFASTER;          PFASTER_PARSE          } from './modules/pfaster'
include { ALLCAPS; ALLCAPS_EVAL; ALLCAPS_PARSE     } from './modules/allcaps'
include { PNEUMOCAT;        PNEUMOCAT_PARSE        } from './modules/pneumocat'
include { SEROCALL;         SEROCALL_PARSE         } from './modules/serocall'
include { PNEUMOTYPER;      PNEUMOTYPER_PARSE      } from './modules/pneumotyper'

// ── Help message ──────────────────────────────────────────────
def helpMessage() {
    log.info """
    =====================================================
     Pneumococcal Serotyping Benchmark  v${workflow.manifest.version}
    =====================================================

    Required:
      --input   PATH   Samplesheet CSV with columns:
                        sample_id, fasta, fastq_1, fastq_2
      --labels  PATH   Ground-truth CSV with columns:
                        Public_ID, Contig_ID, Serotype, Is_capsule

    Optional:
      --multifasta      PATH   Multi-FASTA file to split into per-sample FASTAs
      --allcaps_model   PATH   AllCaps .pth model checkpoint
      --allcaps_repo    PATH   Path to pneumococcal-serotyping repo root
      --outdir          PATH   Output directory [default: results]

    Tool toggles (set --run_<tool>=false to skip):
      --run_seroba      [default: true]
      --run_pneumokity  [default: true]
      --run_pfaster     [default: true]
      --run_allcaps     [default: true]
      --run_pneumocat   [default: false]  (placeholder)
      --run_serocall    [default: false]  (placeholder)
      --run_pneumotyper [default: false]  (placeholder)

    Profiles:
      -profile standard    Local execution
      -profile slurm       SLURM cluster execution
    """.stripIndent()
}

// Show help
if (params.containsKey('help')) {
    helpMessage()
    exit 0
}

// ── Validate inputs ───────────────────────────────────────────
if (!params.input) {
    helpMessage()
    error "Please provide --input samplesheet.csv"
}
if (!params.labels) {
    helpMessage()
    error "Please provide --labels labels.csv"
}

// ── Channels ──────────────────────────────────────────────────

/*
 * Parse the samplesheet into typed channels.
 *
 * Samplesheet CSV columns: sample_id, fasta, fastq_1, fastq_2
 * - fasta may be empty for samples without assembly
 * - fastq_1/fastq_2 may be empty for samples without reads
 */
Channel
    .fromPath(params.input)
    .splitCsv(header: true)
    .map { row ->
        def sid    = row.sample_id
        def fasta  = row.fasta  ? file(row.fasta)  : null
        def fq1    = row.fastq_1 ? file(row.fastq_1) : null
        def fq2    = row.fastq_2 ? file(row.fastq_2) : null
        return [sid, fasta, fq1, fq2]
    }
    .set { ch_samples }

// Branch into FASTA-available and FASTQ-available channels
ch_samples
    .filter { sid, fasta, fq1, fq2 -> fasta != null }
    .map { sid, fasta, fq1, fq2 -> [sid, fasta] }
    .set { ch_fasta }

ch_samples
    .filter { sid, fasta, fq1, fq2 -> fq1 != null && fq2 != null }
    .map { sid, fasta, fq1, fq2 -> [sid, fq1, fq2] }
    .set { ch_fastq }

// Labels file as a value channel (used by multiple processes)
ch_labels = Channel.value(file(params.labels))

// ── Optional: split multi-FASTA ───────────────────────────────

process SPLIT_FASTA {
    tag "split_fasta"
    label 'process_low'

    input:
    path multifasta

    output:
    path "per_sample/*.fasta", emit: fastas

    script:
    """
    mkdir -p per_sample
    split_multifasta.py ${multifasta} per_sample/
    """

    stub:
    """
    mkdir -p per_sample
    echo ">sample1" > per_sample/sample1.fasta
    echo "ATCG"    >> per_sample/sample1.fasta
    """
}

// ── Aggregation ───────────────────────────────────────────────

process COLLECT_PREDICTIONS {
    tag "collect"
    label 'process_low'

    publishDir "${params.outdir}/predictions", mode: 'copy'

    input:
    path '*.csv'

    output:
    path "all_predictions.csv", emit: predictions

    script:
    """
    collect_predictions.py *.csv > all_predictions.csv
    """

    stub:
    """
    echo "sample_id,tool,predicted_serotype" > all_predictions.csv
    """
}

process BUILD_REPORT {
    tag "report"
    label 'process_low'

    publishDir "${params.outdir}/report", mode: 'copy'

    input:
    path predictions
    path labels

    output:
    path "*.csv",            emit: matrices
    path "*.png", optional: true, emit: plots
    path "benchmark_summary.tsv", emit: summary

    script:
    """
    build_confusion_matrix.py \\
        --predictions ${predictions} \\
        --labels ${labels} \\
        --outdir .
    """

    stub:
    """
    echo "tool,accuracy,f1_weighted,f1_macro" > benchmark_summary.tsv
    echo "SeroBA,0.95,0.94,0.90"            >> benchmark_summary.tsv
    """
}

// ── Workflow ──────────────────────────────────────────────────

workflow {

    // If multi-fasta provided, split it and create fasta channel
    if (params.multifasta) {
        SPLIT_FASTA(file(params.multifasta))
        ch_split = SPLIT_FASTA.out.fastas
            .flatten()
            .map { fasta ->
                def sid = fasta.baseName
                return [sid, fasta]
            }
        ch_fasta = ch_fasta.mix(ch_split)
    }

    // Collect all per-tool parsed CSVs here
    ch_parsed = Channel.empty()

    // ── SeroBA v2 (FASTQ) ────────────────────────────────────
    if (params.run_seroba) {
        SEROBA(ch_fastq)
        SEROBA_PARSE(SEROBA.out.predictions)
        ch_parsed = ch_parsed.mix(SEROBA_PARSE.out.parsed)
    }

    // ── PneumoKITy (FASTA assembly) ──────────────────────────
    if (params.run_pneumokity) {
        ch_pneumokity_dir = Channel.value(
            file("${projectDir}/tools/PneumoKITy")
        )
        PNEUMOKITY(ch_fasta, ch_pneumokity_dir)
        PNEUMOKITY_PARSE(PNEUMOKITY.out.predictions)
        ch_parsed = ch_parsed.mix(PNEUMOKITY_PARSE.out.parsed)
    }

    // ── PfaSTer (FASTA) ─────────────────────────────────────
    if (params.run_pfaster) {
        ch_pfaster_dir = Channel.value(
            file("${projectDir}/tools/pfaster")
        )
        PFASTER(ch_fasta, ch_pfaster_dir)
        PFASTER_PARSE(PFASTER.out.predictions)
        ch_parsed = ch_parsed.mix(PFASTER_PARSE.out.parsed)
    }

    // ── AllCaps (FASTA, batch mode) ──────────────────────────
    if (params.run_allcaps && params.allcaps_model && params.allcaps_repo) {
        // Collect all FASTAs into one file for batch processing
        ch_fasta
            .map { sid, fasta -> fasta }
            .collectFile(name: 'all_queries.fasta', newLine: true)
            .set { ch_allcaps_fasta }

        ch_model = Channel.value(file(params.allcaps_model))
        ch_repo  = Channel.value(file(params.allcaps_repo))

        ALLCAPS(ch_allcaps_fasta, ch_model, ch_repo)
        ALLCAPS_EVAL(ALLCAPS.out.predictions, ch_labels, ch_repo)
        ALLCAPS_PARSE(ALLCAPS_EVAL.out.merged)
        ch_parsed = ch_parsed.mix(ALLCAPS_PARSE.out.parsed)
    }

    // ── PneumoCaT (FASTQ, placeholder) ───────────────────────
    if (params.run_pneumocat) {
        PNEUMOCAT(ch_fastq)
        PNEUMOCAT_PARSE(PNEUMOCAT.out.predictions)
        ch_parsed = ch_parsed.mix(PNEUMOCAT_PARSE.out.parsed)
    }

    // ── SeroCall (FASTQ, placeholder) ────────────────────────
    if (params.run_serocall) {
        ch_serocall_dir = Channel.value(
            file("${projectDir}/tools/SeroCall")
        )
        SEROCALL(ch_fastq, ch_serocall_dir)
        SEROCALL_PARSE(SEROCALL.out.predictions)
        ch_parsed = ch_parsed.mix(SEROCALL_PARSE.out.parsed)
    }

    // ── Pneumo-Typer (FASTA dir, placeholder) ────────────────
    if (params.run_pneumotyper) {
        // Pneumo-Typer expects a dir of .fasta files
        ch_fasta
            .map { sid, fasta -> fasta }
            .collect()
            .map { fastas ->
                // Stage all fastas into a directory
                fastas
            }
            .set { ch_pneumotyper_dir }
        PNEUMOTYPER(ch_pneumotyper_dir)
        PNEUMOTYPER_PARSE(PNEUMOTYPER.out.predictions)
        ch_parsed = ch_parsed.mix(PNEUMOTYPER_PARSE.out.parsed)
    }

    // ── Aggregate & Report ───────────────────────────────────
    ch_parsed
        .collect()
        .set { ch_all_parsed }

    COLLECT_PREDICTIONS(ch_all_parsed)
    BUILD_REPORT(COLLECT_PREDICTIONS.out.predictions, ch_labels)
}

/*
 * PneumoCaT — Pneumococcal Capsular Typing (UKHSA)
 * BATCH MODE: processes all samples in a single job
 *
 * Input:     manifest TSV + all FASTQ files staged flat
 * Requires:  Python 2.7, Bowtie2, Samtools — best via container
 * Status:    PLACEHOLDER — not yet implemented
 */

process PNEUMOCAT_BATCH {
    tag "pneumocat_batch"
    label 'process_batch'

    // TODO: build or find a container image with PneumoCaT + deps
    // container 'docker://...'

    publishDir "${params.outdir}/predictions", mode: 'copy'

    input:
    path manifest
    path fastqs

    output:
    path "pneumocat_parsed.csv", emit: parsed

    script:
    error "PneumoCaT process is not yet implemented. Set params.run_pneumocat = false"

    stub:
    """
    echo "sample_id,tool,predicted_serotype" > pneumocat_parsed.csv
    echo "SAMPLE001,PneumoCaT,19F" >> pneumocat_parsed.csv
    """
}

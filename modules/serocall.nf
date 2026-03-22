/*
 * SeroCall — Serotype quantification from paired reads
 * BATCH MODE: processes all samples in a single job
 *
 * Input:     manifest TSV + all FASTQ files staged flat
 * Requires:  BWA >= 0.7.15, Python 2/3
 * Status:    PLACEHOLDER — not yet implemented
 */

process SEROCALL_BATCH {
    tag "serocall_batch"
    label 'process_batch'

    publishDir "${params.outdir}/predictions", mode: 'copy'

    input:
    path manifest
    path fastqs
    path serocall_dir

    output:
    path "serocall_parsed.csv", emit: parsed

    script:
    error "SeroCall process is not yet implemented. Set params.run_serocall = false"

    stub:
    """
    echo "sample_id,tool,predicted_serotype" > serocall_parsed.csv
    echo "SAMPLE001,SeroCall,19F" >> serocall_parsed.csv
    """
}

/*
 * PfaSTer — FASTA-based serotype calling (Pfizer)
 * BATCH MODE: processes all samples in a single job
 *
 * Input:  manifest TSV + all FASTA files staged flat
 * Install: conda env from their environment.yml
 */

process PFASTER_BATCH {
    tag "pfaster_batch"
    label 'process_batch'

    conda "${projectDir}/envs/pfaster.yml"

    publishDir "${params.outdir}/predictions", mode: 'copy'

    input:
    path manifest
    path fastas
    path pfaster_dir

    output:
    path "pfaster_parsed.csv", emit: parsed

    script:
    """
    echo "sample_id,tool,predicted_serotype" > pfaster_parsed.csv
    while IFS=\$'\\t' read -r sample_id fasta_name; do
        mkdir -p "\${sample_id}_output"
        python ${pfaster_dir}/pfaster.py \\
            -f "\${fasta_name}" \\
            -o "\${sample_id}_output"
        parse_pfaster.py "\${sample_id}" "\${sample_id}_output" \\
            | tail -n +2 >> pfaster_parsed.csv
    done < ${manifest}
    """

    stub:
    """
    echo "sample_id,tool,predicted_serotype" > pfaster_parsed.csv
    echo "SAMPLE001,PfaSTer,19F" >> pfaster_parsed.csv
    """
}

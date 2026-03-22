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
    path "errors.log", optional: true, emit: errors

    script:
    """
    echo "sample_id,tool,predicted_serotype" > pfaster_parsed.csv
    ERRORS=0
    while IFS=\$'\\t' read -r sample_id fasta_name; do
        mkdir -p "\${sample_id}_output"
        if python ${pfaster_dir}/pfaster.py \\
            -f "\${fasta_name}" \\
            -o "\${sample_id}_output" 2>>errors.log; then
            parse_pfaster.py "\${sample_id}" "\${sample_id}_output" \\
                | tail -n +2 >> pfaster_parsed.csv
        else
            echo "FAILED: \${sample_id} (exit \$?)" >> errors.log
            echo "\${sample_id},PfaSTer,FAILED" >> pfaster_parsed.csv
            ERRORS=\$((ERRORS + 1))
        fi
    done < ${manifest}
    if [ \$ERRORS -gt 0 ]; then
        echo "\${ERRORS} sample(s) failed — see errors.log" >&2
    fi
    """

    stub:
    """
    echo "sample_id,tool,predicted_serotype" > pfaster_parsed.csv
    echo "SAMPLE001,PfaSTer,19F" >> pfaster_parsed.csv
    """
}

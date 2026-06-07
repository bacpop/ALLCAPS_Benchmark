/*
 * PneumoKITy — kmer-based serotyping using Mash
 * BATCH MODE: processes all samples in a single job
 *
 * Supports FASTA (assembly) via pure -a mode.
 * Install: conda env with Python 3.7+, mash >=2.0, numpy, pandas, sqlalchemy
 */

process PNEUMOKITY_BATCH {
    tag "pneumokity_batch"
    label 'process_batch'

    conda "${projectDir}/envs/pneumokity.yml"

    publishDir "${params.outdir}/predictions", mode: 'copy'

    input:
    path manifest
    path fastas
    path pneumokity_dir

    output:
    path "pneumokity_parsed.csv", emit: parsed
    path "errors.log", optional: true, emit: errors

    script:
    """
    echo "sample_id,tool,predicted_serotype" > pneumokity_parsed.csv
    ERRORS=0
    while IFS=, read -r sample_id fasta_name; do
        if python ${pneumokity_dir}/pneumokity.py pure \\
            -a "\${fasta_name}" \\
            -o "\${sample_id}_output" \\
            -s "\${sample_id}" \\
            -t ${task.cpus} 2>>errors.log; then
            parse_pneumokity.py "\${sample_id}" \\
                "\${sample_id}_output/pneumo_capsular_typing/\${sample_id}_result_data.csv" \\
                | tail -n +2 >> pneumokity_parsed.csv
        else
            echo "FAILED: \${sample_id} (exit \$?)" >> errors.log
            echo "\${sample_id},PneumoKITy,FAILED" >> pneumokity_parsed.csv
            ERRORS=\$((ERRORS + 1))
        fi
    done < ${manifest}
    if [ \$ERRORS -gt 0 ]; then
        echo "\${ERRORS} sample(s) failed — see errors.log" >&2
    fi
    """

    stub:
    """
    echo "sample_id,tool,predicted_serotype" > pneumokity_parsed.csv
    echo "SAMPLE001,PneumoKITy,19F" >> pneumokity_parsed.csv
    """
}

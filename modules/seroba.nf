/*
 * SeroBA v2 — k-mer-based serotyping from Illumina paired reads
 * BATCH MODE: processes all samples in a single job
 *
 * Container: docker://sangerbentleygroup/seroba
 * Input:     manifest TSV (sample_id, fq1, fq2) + all FASTQ files staged flat
 * Output:    single parsed CSV for all samples
 */

process SEROBA_BATCH {
    tag "seroba_batch"
    label 'process_batch'

    container 'docker://sangerbentleygroup/seroba'

    publishDir "${params.outdir}/predictions", mode: 'copy'

    input:
    path manifest
    path fastqs

    output:
    path "seroba_parsed.csv", emit: parsed
    path "errors.log", optional: true, emit: errors

    script:
    """
    echo "sample_id,tool,predicted_serotype" > seroba_parsed.csv
    ERRORS=0
    while IFS=\$'\\t' read -r sample_id fq1 fq2; do
        if seroba runSerotyping \\
            /seroba/database \\
            "\${fq1}" \\
            "\${fq2}" \\
            "\${sample_id}_result" 2>>errors.log; then
            parse_seroba.py "\${sample_id}" "\${sample_id}_result/pred.tsv" \\
                | tail -n +2 >> seroba_parsed.csv
        else
            echo "FAILED: \${sample_id} (exit \$?)" >> errors.log
            echo "\${sample_id},SeroBA,FAILED" >> seroba_parsed.csv
            ERRORS=\$((ERRORS + 1))
        fi
    done < ${manifest}
    if [ \$ERRORS -gt 0 ]; then
        echo "\${ERRORS} sample(s) failed — see errors.log" >&2
    fi
    """

    stub:
    """
    echo "sample_id,tool,predicted_serotype" > seroba_parsed.csv
    echo "SAMPLE001,SeroBA,19F" >> seroba_parsed.csv
    """
}

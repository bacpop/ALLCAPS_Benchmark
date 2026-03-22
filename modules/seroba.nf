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

    script:
    """
    echo "sample_id,tool,predicted_serotype" > seroba_parsed.csv
    while IFS=\$'\\t' read -r sample_id fq1 fq2; do
        seroba runSerotyping \\
            /seroba/database \\
            "\${fq1}" \\
            "\${fq2}" \\
            "\${sample_id}_result"
        parse_seroba.py "\${sample_id}" "\${sample_id}_result/pred.tsv" \\
            | tail -n +2 >> seroba_parsed.csv
    done < ${manifest}
    """

    stub:
    """
    echo "sample_id,tool,predicted_serotype" > seroba_parsed.csv
    echo "SAMPLE001,SeroBA,19F" >> seroba_parsed.csv
    """
}

/*
 * SeroBA v2 — k-mer-based serotyping from Illumina paired reads
 * PER-SAMPLE MODE: each sample runs as an independent Nextflow process,
 * allowing SLURM to schedule them fully in parallel.
 *
 * Container: docker://sangerbentleygroup/seroba
 * Input:     tuple (sample_id, fq1, fq2)
 * Output:    one-row CSV (no header) per sample; caller collectFiles into
 *            seroba_parsed.csv with header seed
 */

process SEROBA_SINGLE {
    tag "${sample_id}"
    label 'process_seroba'

    container 'docker://sangerbentleygroup/seroba'

    input:
    tuple val(sample_id), path(fq1), path(fq2)

    output:
    path "${sample_id}.csv", emit: row

    script:
    """
    if seroba runSerotyping \\
            /seroba/database \\
            "${fq1}" \\
            "${fq2}" \\
            result 2>errors.log; then
        parse_seroba.py "${sample_id}" result/pred.csv \\
            | tail -n +2 > "${sample_id}.csv"
    else
        echo "${sample_id},SeroBA,FAILED" > "${sample_id}.csv"
    fi
    """

    stub:
    """
    echo "${sample_id},SeroBA,19F" > "${sample_id}.csv"
    """
}

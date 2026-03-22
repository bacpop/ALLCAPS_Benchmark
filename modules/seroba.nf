/*
 * SeroBA v2 — k-mer-based serotyping from Illumina paired reads
 *
 * Container: docker://sangerbentleygroup/seroba
 * Input:     paired FASTQ
 * Output:    pred.tsv per sample
 */

process SEROBA {
    tag "$sample_id"
    label 'process_medium'

    container 'docker://sangerbentleygroup/seroba'

    input:
    tuple val(sample_id), path(fastq_1), path(fastq_2)

    output:
    tuple val(sample_id), path("${sample_id}_result/pred.tsv"), emit: predictions

    script:
    """
    seroba runSerotyping \\
        /seroba/database \\
        ${fastq_1} \\
        ${fastq_2} \\
        ${sample_id}_result
    """

    stub:
    """
    mkdir -p ${sample_id}_result
    printf 'Predicted Serotype:\\t19F\\n' > ${sample_id}_result/pred.tsv
    """
}

process SEROBA_PARSE {
    tag "$sample_id"
    label 'process_low'

    input:
    tuple val(sample_id), path(pred_tsv)

    output:
    path "${sample_id}.seroba.csv", emit: parsed

    script:
    """
    parse_seroba.py ${sample_id} ${pred_tsv} > ${sample_id}.seroba.csv
    """

    stub:
    """
    echo "sample_id,tool,predicted_serotype" > ${sample_id}.seroba.csv
    echo "${sample_id},SeroBA,19F" >> ${sample_id}.seroba.csv
    """
}

/*
 * PneumoCaT — Pneumococcal Capsular Typing (UKHSA)
 *
 * Input:     Paired FASTQ only
 * Requires:  Python 2.7, Bowtie2, Samtools — best via container
 * Status:    PLACEHOLDER — not yet implemented
 */

process PNEUMOCAT {
    tag "$sample_id"
    label 'process_medium'

    // TODO: build or find a container image with PneumoCaT + deps
    // container 'docker://...'

    input:
    tuple val(sample_id), path(fastq_1), path(fastq_2)

    output:
    tuple val(sample_id), path("${sample_id}_pneumocat/pneumo_capsular_typing/${sample_id}.results.xml"), emit: predictions

    script:
    error "PneumoCaT process is not yet implemented. Set params.run_pneumocat = false"

    stub:
    """
    mkdir -p ${sample_id}_pneumocat/pneumo_capsular_typing
    echo '<result type="Serotype"><value>19F</value></result>' > ${sample_id}_pneumocat/pneumo_capsular_typing/${sample_id}.results.xml
    """
}

process PNEUMOCAT_PARSE {
    tag "$sample_id"
    label 'process_low'

    input:
    tuple val(sample_id), path(result_xml)

    output:
    path "${sample_id}.pneumocat.csv", emit: parsed

    script:
    """
    parse_pneumocat.py ${sample_id} ${result_xml} > ${sample_id}.pneumocat.csv
    """

    stub:
    """
    echo "sample_id,tool,predicted_serotype" > ${sample_id}.pneumocat.csv
    echo "${sample_id},PneumoCaT,19F"       >> ${sample_id}.pneumocat.csv
    """
}

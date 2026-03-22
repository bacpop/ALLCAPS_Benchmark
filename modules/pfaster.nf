/*
 * PfaSTer — FASTA-based serotype calling (Pfizer)
 *
 * Input:  FASTA only
 * Install: conda env from their environment.yml
 */

process PFASTER {
    tag "$sample_id"
    label 'process_low'

    conda "${projectDir}/envs/pfaster.yml"

    input:
    tuple val(sample_id), path(fasta)
    path pfaster_dir  // cloned pfaster repo

    output:
    tuple val(sample_id), path("${sample_id}_output"), emit: predictions

    script:
    """
    mkdir -p ${sample_id}_output
    python ${pfaster_dir}/pfaster.py \\
        -f ${fasta} \\
        -o ${sample_id}_output
    """

    stub:
    """
    mkdir -p ${sample_id}_output
    echo "Serotype: 19F" > ${sample_id}_output/result.txt
    """
}

process PFASTER_PARSE {
    tag "$sample_id"
    label 'process_low'

    input:
    tuple val(sample_id), path(output_dir)

    output:
    path "${sample_id}.pfaster.csv", emit: parsed

    script:
    """
    parse_pfaster.py ${sample_id} ${output_dir} > ${sample_id}.pfaster.csv
    """

    stub:
    """
    echo "sample_id,tool,predicted_serotype" > ${sample_id}.pfaster.csv
    echo "${sample_id},PfaSTer,19F" >> ${sample_id}.pfaster.csv
    """
}

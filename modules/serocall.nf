/*
 * SeroCall — Serotype quantification from paired reads
 *
 * Input:     Paired FASTQ
 * Requires:  BWA >= 0.7.15, Python 2/3
 * Status:    PLACEHOLDER — not yet implemented
 */

process SEROCALL {
    tag "$sample_id"
    label 'process_medium'

    input:
    tuple val(sample_id), path(fastq_1), path(fastq_2)
    path serocall_dir  // cloned SeroCall repo

    output:
    tuple val(sample_id), path("${sample_id}_calls.txt"), emit: predictions

    script:
    error "SeroCall process is not yet implemented. Set params.run_serocall = false"

    stub:
    """
    cat <<EOF > ${sample_id}_calls.txt
    ##fileformat=SeroCallv1.0
    ##NumReads=1000
    ##NumCapsule=500
    #SEROTYPE\tPERCENTAGE
    19F\t100.0%
    EOF
    """
}

process SEROCALL_PARSE {
    tag "$sample_id"
    label 'process_low'

    input:
    tuple val(sample_id), path(calls_txt)

    output:
    path "${sample_id}.serocall.csv", emit: parsed

    script:
    """
    parse_serocall.py ${sample_id} ${calls_txt} > ${sample_id}.serocall.csv
    """

    stub:
    """
    echo "sample_id,tool,predicted_serotype" > ${sample_id}.serocall.csv
    echo "${sample_id},SeroCall,19F"        >> ${sample_id}.serocall.csv
    """
}

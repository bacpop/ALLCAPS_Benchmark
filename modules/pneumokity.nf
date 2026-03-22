/*
 * PneumoKITy — kmer-based serotyping using Mash
 *
 * Supports FASTA (assembly) or paired FASTQ.
 * Here we use assembly mode (pure -a) for simplicity.
 *
 * Install: conda env with Python 3.7+, mash >=2.0, numpy, pandas, sqlalchemy
 */

process PNEUMOKITY {
    tag "$sample_id"
    label 'process_medium'

    conda "${projectDir}/envs/pneumokity.yml"

    input:
    tuple val(sample_id), path(fasta)
    path pneumokity_dir  // cloned PneumoKITy repo

    output:
    tuple val(sample_id), path("${sample_id}_output/pneumo_capsular_typing/${sample_id}_result_data.csv"), emit: predictions

    script:
    """
    python ${pneumokity_dir}/pneumokity.py pure \\
        -a ${fasta} \\
        -o ${sample_id}_output \\
        -s ${sample_id} \\
        -t ${task.cpus}
    """

    stub:
    """
    mkdir -p ${sample_id}_output/pneumo_capsular_typing
    echo "predicted serotype,top hits,max percent,folder,stage 1 result,rag status" > ${sample_id}_output/pneumo_capsular_typing/${sample_id}_result_data.csv
    echo "19F,19F:98.5,98.5,,type,GREEN" >> ${sample_id}_output/pneumo_capsular_typing/${sample_id}_result_data.csv
    """
}

process PNEUMOKITY_PARSE {
    tag "$sample_id"
    label 'process_low'

    input:
    tuple val(sample_id), path(result_csv)

    output:
    path "${sample_id}.pneumokity.csv", emit: parsed

    script:
    """
    parse_pneumokity.py ${sample_id} ${result_csv} > ${sample_id}.pneumokity.csv
    """

    stub:
    """
    echo "sample_id,tool,predicted_serotype" > ${sample_id}.pneumokity.csv
    echo "${sample_id},PneumoKITy,19F" >> ${sample_id}.pneumokity.csv
    """
}

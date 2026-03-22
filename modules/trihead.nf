/*
 * TriHead — Your transformer-based serotyping tool
 *
 * Runs process_trihead_query.py on FASTA input,
 * then eval_test_performance.py to get confusion matrix.
 *
 * Expects the pneumococcal-serotyping repo and ebi_env conda environment.
 */

process TRIHEAD {
    tag "trihead_batch"
    label 'process_high'

    // Uses your existing conda env on the HPC (no env file needed)
    // Set conda directive to your env name or leave blank to use module system
    conda params.trihead_conda ?: null

    input:
    path query_fasta
    path model
    path trihead_repo

    output:
    path "trihead_out/query_results.csv", emit: predictions

    script:
    """
    mkdir -p trihead_out
    TASK_DIR=\$PWD

    cd ${trihead_repo}
    python -m src.scripts.trihead.process_trihead_query \\
        --query \${TASK_DIR}/${query_fasta} \\
        --model_path \${TASK_DIR}/${model} \\
        --output_dir \${TASK_DIR}/trihead_out \\
        --inference_mode eval
    cd \${TASK_DIR}
    """

    stub:
    """
    mkdir -p trihead_out
    echo "record_id,pred_argmax,pred_genogroup,energy" > trihead_out/query_results.csv
    echo "sample1,19F,19F,-10.5" >> trihead_out/query_results.csv
    """
}

process TRIHEAD_EVAL {
    tag "trihead_eval"
    label 'process_low'

    conda params.trihead_conda ?: null

    input:
    path query_results
    path labels
    path trihead_repo

    output:
    path "trihead_eval/merged_query_results.csv", emit: merged
    path "trihead_eval/serotype_report.txt",      emit: report
    path "trihead_eval/serotype_confusion_matrix.csv", emit: confusion_matrix

    script:
    """
    mkdir -p trihead_eval
    TASK_DIR=\$PWD

    cd ${trihead_repo}
    python -m src.scripts.eval_test_performance \\
        --query_results \${TASK_DIR}/${query_results} \\
        --metadata \${TASK_DIR}/${labels} \\
        --output_dir \${TASK_DIR}/trihead_eval
    cd \${TASK_DIR}
    """

    stub:
    """
    mkdir -p trihead_eval
    echo "record_id,true_serotype,pred_serotype" > trihead_eval/merged_query_results.csv
    echo "sample1,19F,19F"                       >> trihead_eval/merged_query_results.csv
    echo "Accuracy: 1.0"                          > trihead_eval/serotype_report.txt
    echo ",19F"                                    > trihead_eval/serotype_confusion_matrix.csv
    echo "19F,1"                                  >> trihead_eval/serotype_confusion_matrix.csv
    """
}

process TRIHEAD_PARSE {
    tag "trihead_parse"
    label 'process_low'

    input:
    path merged_csv

    output:
    path "trihead.csv", emit: parsed

    script:
    """
    parse_trihead.py ${merged_csv} > trihead.csv
    """

    stub:
    """
    echo "sample_id,tool,predicted_serotype" > trihead.csv
    echo "sample1,TriHead,19F"              >> trihead.csv
    """
}

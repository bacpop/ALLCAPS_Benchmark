/*
 * AllCaps — Our transformer-based serotyping tool
 *
 * Runs process_allcaps_query.py on FASTA input,
 * then eval_test_performance.py to get confusion matrix.
 *
 * Expects the pneumococcal-serotyping repo and ebi_env conda environment.
 */

process ALLCAPS {
    tag "allcaps_batch"
    label 'process_high'

    // Uses your existing conda env on the HPC (no env file needed)
    // Set conda directive to your env name or leave blank to use module system
    // conda params.allcaps_conda ?: null

    input:
    path query_fasta
    path model
    path allcaps_repo

    output:
    path "allcaps_out/query_results.csv", emit: predictions

    script:
    """
    mkdir -p allcaps_out
    TASK_DIR=\$PWD

    cd ${allcaps_repo}
    python -m src.scripts.allcaps.process_allcaps_query \\
        --query \${TASK_DIR}/${query_fasta} \\
        --model_path \${TASK_DIR}/${model} \\
        --output_dir \${TASK_DIR}/allcaps_out \\
        --inference_mode eval
    cd \${TASK_DIR}
    """

    stub:
    """
    mkdir -p allcaps_out
    echo "record_id,pred_argmax,pred_genogroup,energy" > allcaps_out/query_results.csv
    echo "sample1,19F,19F,-10.5" >> allcaps_out/query_results.csv
    """
}

process ALLCAPS_EVAL {
    tag "allcaps_eval"
    label 'process_low'

    // conda params.allcaps_conda ?: null

    input:
    path query_results
    path labels
    path allcaps_repo

    output:
    path "allcaps_eval/merged_query_results.csv", emit: merged
    path "allcaps_eval/serotype_report.txt",      emit: report
    path "allcaps_eval/serotype_confusion_matrix.csv", emit: confusion_matrix

    script:
    """
    mkdir -p allcaps_eval
    TASK_DIR=\$PWD

    cd ${allcaps_repo}
    python -m src.scripts.eval_test_performance \\
        --query_results \${TASK_DIR}/${query_results} \\
        --metadata \${TASK_DIR}/${labels} \\
        --output_dir \${TASK_DIR}/allcaps_eval
    cd \${TASK_DIR}
    """

    stub:
    """
    mkdir -p allcaps_eval
    echo "record_id,true_serotype,pred_serotype" > allcaps_eval/merged_query_results.csv
    echo "sample1,19F,19F"                       >> allcaps_eval/merged_query_results.csv
    echo "Accuracy: 1.0"                          > allcaps_eval/serotype_report.txt
    echo ",19F"                                    > allcaps_eval/serotype_confusion_matrix.csv
    echo "19F,1"                                  >> allcaps_eval/serotype_confusion_matrix.csv
    """
}

process ALLCAPS_PARSE {
    tag "allcaps_parse"
    label 'process_low'

    input:
    path merged_csv

    output:
    path "allcaps.csv", emit: parsed

    script:
    """
    parse_allcaps.py ${merged_csv} > allcaps.csv
    """

    stub:
    """
    echo "sample_id,tool,predicted_serotype" > allcaps.csv
    echo "sample1,AllCaps,19F"              >> allcaps.csv
    """
}

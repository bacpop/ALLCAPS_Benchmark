/*
 * SeroCall — Pneumococcal serotype identification & quantification from reads
 * PER-SAMPLE MODE: each sample runs as an independent Nextflow process,
 * allowing SLURM to schedule them fully in parallel.
 *
 * SeroCall has no container/conda/pip distribution (the upstream README
 * lists those as "forthcoming"), so the repo is cloned into tools/SeroCall
 * (like PfaSTer) and passed in as `serocall_dir`. The clone already ships
 * the pre-built BWA index in data/, so no indexing step is required — only
 * `bwa` (>=0.7.15) and `python` need to be on PATH (provided via conda).
 *
 * Invocation:  serocall [-o OUTPUT] [-t THREADS] r1file r2file
 * Output:      <prefix>_calls.txt  — final serotype calls (header lines +
 *              tab-separated SEROTYPE<TAB>PERCENTAGE, highest abundance first)
 *              <prefix>_counts.txt — intermediate bin counts (ignored here)
 *
 * Emits one-row CSV (no header) per sample; caller collectFiles into
 * serocall_parsed.csv with header seed.
 */

process SEROCALL_SINGLE {
    tag "${sample_id}"
    label 'process_serocall'

    conda "${projectDir}/envs/serocall.yml"

    input:
    tuple val(sample_id), path(fq1), path(fq2)
    path serocall_dir

    output:
    path "${sample_id}.csv", emit: row

    script:
    """
    # NOTE: the serocall wrapper exits 0 even when the internal serocall.py
    # quantification step fails, so we can't rely on its exit code. Instead we
    # check that the _calls.txt output was actually produced.
    ${serocall_dir}/serocall \\
        -t ${task.cpus} \\
        -o "${sample_id}" \\
        "${fq1}" \\
        "${fq2}" 2>errors.log || true

    if [ -s "${sample_id}_calls.txt" ]; then
        parse_serocall.py "${sample_id}" "${sample_id}_calls.txt" \\
            | tail -n +2 > "${sample_id}.csv"
    else
        echo "MISSING_CALLS: ${sample_id} — see errors.log" >&2
        echo "${sample_id},SeroCall,FAILED" > "${sample_id}.csv"
    fi
    """

    stub:
    """
    echo "${sample_id},SeroCall,19F" > "${sample_id}.csv"
    """
}

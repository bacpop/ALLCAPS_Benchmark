/*
 * PfaSTer — FASTA-based serotype calling (Pfizer)
 * PER-SAMPLE MODE: each sample runs as an independent Nextflow process,
 * allowing SLURM to schedule them fully in parallel.
 *
 * Install: conda env from envs/pfaster.yml (mirrors their environment.yml).
 * The repo is cloned into tools/pfaster and passed in as `pfaster_dir`.
 *
 * Input:   tuple (sample_id, fasta)
 * Output:  one-row CSV (no header) per sample; caller collectFiles into
 *          pfaster_parsed.csv with header seed.
 *
 * Logging: pfaster.py runs unbuffered (PYTHONUNBUFFERED / -u) and its
 * stdout+stderr flow to the task's .command.out/.command.err so failures are
 * actually inspectable in the work dir (buffered output was previously lost
 * when a batch job was killed).
 */

process PFASTER_SINGLE {
    tag "${sample_id}"
    label 'process_pfaster'

    conda "${projectDir}/envs/pfaster.yml"

    input:
    tuple val(sample_id), path(fasta)
    path pfaster_dir

    output:
    path "${sample_id}.csv", emit: row

    script:
    """
    export PYTHONUNBUFFERED=1
    mkdir -p "${sample_id}_output"
    # pfaster.py opens its references (ref/, model/) via paths relative to the
    # CWD, assuming it is run from the repo root. Under Nextflow the CWD is this
    # task dir, so expose those dirs here without cd-ing into the (read-only)
    # install — pfaster also writes scratch files into the CWD.
    ln -sf "${pfaster_dir}/ref" ref
    ln -sf "${pfaster_dir}/model" model
    if python -u ${pfaster_dir}/pfaster.py \\
            -f "${fasta}" \\
            -o "${sample_id}_output"; then
        parse_pfaster.py "${sample_id}" "${sample_id}_output" \\
            | tail -n +2 > "${sample_id}.csv"
    else
        echo "PfaSTer failed for ${sample_id} (exit \$?)" >&2
        echo "${sample_id},PfaSTer,FAILED" > "${sample_id}.csv"
    fi
    """

    stub:
    """
    echo "${sample_id},PfaSTer,19F" > "${sample_id}.csv"
    """
}

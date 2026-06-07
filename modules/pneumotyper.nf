/*
 * Pneumo-Typer — capsule genotype + serotype/ST prediction (Perl)
 * BATCH MODE: Pneumo-Typer natively consumes a *directory* of genomes and
 * emits one combined Serotype.out, so (like PneumoKITy/PfaSTer) it runs as a
 * single job over all samples rather than one job per sample.
 *
 * No container/conda package is used for the clone itself; the upstream
 * bioconda recipe's runtime deps are mirrored in envs/pneumotyper.yml and the
 * cloned pneumo-typer.pl is driven directly. The repo is passed in as
 * `pneumotyper_dir` (cloned into tools/Pneumo-Typer, like PfaSTer/SeroCall).
 *
 * Input:    manifest TSV (sample_id<TAB>fasta_filename) + all FASTA files
 *           staged flat. Genomes are symlinked into genomes/<sample_id>.fasta
 *           so Pneumo-Typer's Strain column equals our sample_id.
 * Flags:    -m F skips MLST (we only want the serotype call, and skipping it
 *           avoids the optional MLST/cgMLST dataset downloads).
 * Output:   <out>/Serotype.out — "Strain<TAB>Serotype", one row per genome.
 */

process PNEUMOTYPER {
    tag "pneumotyper_batch"
    label 'process_high'

    conda "${projectDir}/envs/pneumotyper.yml"

    input:
    path manifest
    path fastas
    path pneumotyper_dir

    output:
    path "pneumotyper_out/Serotype.out", emit: predictions
    path "errors.log", optional: true, emit: errors

    script:
    """
    # Stage genomes into a directory, renamed to sample_id so the Strain
    # column in Serotype.out matches our sample IDs.
    mkdir -p genomes
    while IFS=, read -r sample_id fasta_name; do
        [ -z "\${sample_id}" ] && continue
        ln -sf "../\${fasta_name}" "genomes/\${sample_id}.fasta"
    done < ${manifest}

    perl ${pneumotyper_dir}/pneumo-typer.pl \\
        -d genomes \\
        -o pneumotyper_out \\
        -m F \\
        -t ${task.cpus} 2>errors.log

    if [ ! -f pneumotyper_out/Serotype.out ]; then
        echo "Pneumo-Typer did not produce Serotype.out — see errors.log" >&2
        exit 1
    fi
    """

    stub:
    """
    mkdir -p pneumotyper_out
    printf 'Strain\\tSerotype\\n' > pneumotyper_out/Serotype.out
    printf 'sample1\\t19F\\n'    >> pneumotyper_out/Serotype.out
    """
}

process PNEUMOTYPER_PARSE {
    tag "pneumotyper_parse"
    label 'process_low'

    publishDir "${params.outdir}/predictions", mode: 'copy'

    input:
    path serotype_out

    output:
    path "pneumotyper_parsed.csv", emit: parsed

    script:
    """
    parse_pneumotyper.py ${serotype_out} > pneumotyper_parsed.csv
    """

    stub:
    """
    echo "sample_id,tool,predicted_serotype" > pneumotyper_parsed.csv
    echo "sample1,Pneumo-Typer,19F"          >> pneumotyper_parsed.csv
    """
}

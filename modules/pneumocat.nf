/*
 * PneumoCaT — Pneumococcal Capsular Typing (UKHSA)
 * PER-SAMPLE MODE: each sample runs as an independent Nextflow process,
 * allowing SLURM to schedule them fully in parallel.
 *
 * Input:     tuple (sample_id, fq1, fq2)
 * Requires:  PneumoCaT (bioconda), Bowtie2, Samtools
 *
 * PneumoCaT expects FASTQ filenames with dot-separated read numbers
 * (e.g. SAMPLE.1.fastq.gz). If the input uses underscore-separated names
 * (SAMPLE_1.fastq.gz), symlinks are created to match the expected pattern.
 *
 * Output XML is at:
 *   <outdir>/SAMPLEID.results.xml             (step 1 only)
 *   <outdir>/SNP_based_serotyping/SAMPLEID.results.xml  (step 2)
 *
 * Output:    one-row CSV (no header) per sample; caller collectFiles into
 *            pneumocat_parsed.csv with header seed
 */

process PNEUMOCAT_SINGLE {
    tag "${sample_id}"
    label 'process_pneumocat'

    input:
    tuple val(sample_id), path(fq1), path(fq2)

    output:
    path "${sample_id}.csv", emit: row

    script:
    """
    # Create dot-separated symlinks so PneumoCaT extracts clean SAMPLEID
    ln -sf "${fq1}" "${sample_id}.1.fastq.gz"
    ln -sf "${fq2}" "${sample_id}.2.fastq.gz"

    outdir="${sample_id}_pneumocat"
    if PneumoCaT.py \\
        -1 "${sample_id}.1.fastq.gz" \\
        -2 "${sample_id}.2.fastq.gz" \\
        -o "\${outdir}" \\
        --cleanup 2>errors.log; then

        # Step 2 XML (variant-based) takes precedence over step 1
        xml="\${outdir}/${sample_id}.results.xml"  # TODO - Swap the order?
        if [ ! -f "\${xml}" ]; then
            xml="\${outdir}/SNP_based_serotyping/${sample_id}.results.xml"
        fi

        if [ -f "\${xml}" ]; then
            parse_pneumocat.py "${sample_id}" "\${xml}" \\
                | tail -n +2 > "${sample_id}.csv"
        else
            echo "MISSING_XML: ${sample_id}" >> errors.log
            echo "${sample_id},PneumoCaT,FAILED" > "${sample_id}.csv"
        fi
    else
        echo "FAILED: ${sample_id} (exit \$?)" >> errors.log
        echo "${sample_id},PneumoCaT,FAILED" > "${sample_id}.csv"
    fi
    """

    stub:
    """
    echo "${sample_id},PneumoCaT,19F" > "${sample_id}.csv"
    """
}

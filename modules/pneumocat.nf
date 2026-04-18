/*
 * PneumoCaT — Pneumococcal Capsular Typing (UKHSA)
 * BATCH MODE: processes all samples in a single job
 *
 * Input:     manifest TSV (sample_id, fq1, fq2) + all FASTQ files staged flat
 * Requires:  PneumoCaT (bioconda), Bowtie2, Samtools
 *
 * PneumoCaT expects FASTQ filenames with dot-separated read numbers
 * (e.g. SAMPLE.1.fastq.gz). If the input uses underscore-separated names
 * (SAMPLE_1.fastq.gz), symlinks are created to match the expected pattern.
 *
 * Output XML is at:
 *   <outdir>/SAMPLEID.results.xml             (step 1 only)
 *   <outdir>/SNP_based_serotyping/SAMPLEID.results.xml  (step 2)
 */

process PNEUMOCAT_BATCH {
    tag "pneumocat_batch"
    label 'process_batch'

    publishDir "${params.outdir}/predictions", mode: 'copy'

    input:
    path manifest
    path fastqs

    output:
    path "pneumocat_parsed.csv", emit: parsed
    path "errors.log", optional: true, emit: errors

    script:
    """
    echo "sample_id,tool,predicted_serotype" > pneumocat_parsed.csv
    ERRORS=0
    while IFS=\$'\\t' read -r sample_id fq1 fq2; do
        # Create dot-separated symlinks so PneumoCaT extracts clean SAMPLEID
        ln -sf "\${fq1}" "\${sample_id}.1.fastq.gz"
        ln -sf "\${fq2}" "\${sample_id}.2.fastq.gz"

        outdir="\${sample_id}_pneumocat"
        if PneumoCaT.py \\
            -1 "\${sample_id}.1.fastq.gz" \\
            -2 "\${sample_id}.2.fastq.gz" \\
            -o "\${outdir}" \\
            --cleanup 2>>errors.log; then

            # Step 2 XML (variant-based) takes precedence over step 1
            xml="\${outdir}/\${sample_id}.results.xml"  # TODO - Swap the order?
            if [ ! -f "\${xml}" ]; then
                xml="\${outdir}/SNP_based_serotyping/\${sample_id}.results.xml"
            fi

            if [ -f "\${xml}" ]; then
                parse_pneumocat.py "\${sample_id}" "\${xml}" \\
                    | tail -n +2 >> pneumocat_parsed.csv
            else
                echo "MISSING_XML: \${sample_id}" >> errors.log
                echo "\${sample_id},PneumoCaT,FAILED" >> pneumocat_parsed.csv
                ERRORS=\$((ERRORS + 1))
            fi
        else
            echo "FAILED: \${sample_id} (exit \$?)" >> errors.log
            echo "\${sample_id},PneumoCaT,FAILED" >> pneumocat_parsed.csv
            ERRORS=\$((ERRORS + 1))
        fi

        # Clean up symlinks
        rm -f "\${sample_id}.1.fastq.gz" "\${sample_id}.2.fastq.gz"
    done < ${manifest}
    if [ \$ERRORS -gt 0 ]; then
        echo "\${ERRORS} sample(s) failed — see errors.log" >&2
    fi
    """

    stub:
    """
    echo "sample_id,tool,predicted_serotype" > pneumocat_parsed.csv
    echo "SAMPLE001,PneumoCaT,19F" >> pneumocat_parsed.csv
    """
}

#!/bin/bash
#SBATCH --job-name=flankingseq_minimap 
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=email@ufl.edu
#SBATCH --ntasks=1
#SBATCH --mem=XXgb 
#SBATCH --nodes=1
#SBATCH --cpus-per-task=XX 
#SBATCH --time=1-00:00:00 
#SBATCH --output=flankingseq_minimap_%j.log
#SBATCH --account=group
#SBATCH --qos=group-b

# Load necessary modules and activate environment
module load conda
conda activate python3_env

# Export the path to the conda environment bin directory
export PATH=/path/to/.conda/envs/python3_env/bin:$PATH # Placeholder for conda environment path

# Main directory path (consistent with previous scripts)
MAIN_DIR="/path/to/AtNPR1citrus_seq" # Placeholder: Update to your actual base data path

# Define input and output directories
SEQ_A="${MAIN_DIR}/references/TDNAsequences/AtNPR1citrus_TDNA.fa"  # Placeholder for TDNA sequence Forward strand
SEQ_A_REVCOM="${MAIN_DIR}/references/TDNAsequences/AtNPR1citrus_TDNArevcom.fa"  # Placeholder for Reverse complement strand
SEQ_B_DIR="${MAIN_DIR}/AtNPR1_genomelocation_qc15_fixedAtNPR1/" # Input directory for contigs mapped to TDNA (output from 3_align_contigs_to_TDNA.sh)
OUTPUT_DIR="${MAIN_DIR}/unmapped_fragments/" # Output directory for unmapped fragments (flanking regions)

# Create output directory if not exists
mkdir -p "${OUTPUT_DIR}"

# Create log file for the script
LOG_FILE="${OUTPUT_DIR}/minimap_run.log"
touch "$LOG_FILE"

echo "Starting flanking region extraction workflow." >> "$LOG_FILE"
echo "Input contigs directory: $SEQ_B_DIR" >> "$LOG_FILE"
echo "Output fragments directory: $OUTPUT_DIR" >> "$LOG_FILE"

# Loop through each Sequence B (contigs mapped to TDNA)
for SEQ_B in "${SEQ_B_DIR}"/*.fasta; do
    BASENAME=$(basename "${SEQ_B}" .fasta)

    echo "Processing ${BASENAME} - Starting minimap2 alignment" >> "$LOG_FILE"

    # Align forward strand of Sequence A (TDNA) to Sequence B (contigs)
    # This aligns the TDNA to the contigs to find where the TDNA is located within the contig.
    minimap2 -a "${SEQ_B}" "${SEQ_A}" > "${OUTPUT_DIR}/${BASENAME}_forward.sam" 2>> "$LOG_FILE"
    if [ $? -eq 0 ]; then
        touch "${OUTPUT_DIR}/${BASENAME}_forward_complete.flag"
        echo "Forward alignment completed for ${BASENAME}" >> "$LOG_FILE"
    else
        echo "Error in forward alignment for ${BASENAME}" >> "$LOG_FILE"
    fi

    # Align reverse complement strand of Sequence A (TDNA)
    minimap2 -a "${SEQ_B}" "${SEQ_A_REVCOM}" > "${OUTPUT_DIR}/${BASENAME}_revcom.sam" 2>> "$LOG_FILE"
    if [ $? -eq 0 ]; then
        if [ -s "${OUTPUT_DIR}/${BASENAME}_revcom.sam" ]; then  # Check if SAM file is non-empty
            touch "${OUTPUT_DIR}/${BASENAME}_revcom_complete.flag"
            echo "Reverse complement alignment completed for ${BASENAME}" >> "$LOG_FILE"
        else
            echo "Reverse complement SAM file is empty for ${BASENAME}, skipping." >> "$LOG_FILE"
        fi
    else
        echo "Error in reverse complement alignment for ${BASENAME}" >> "$LOG_FILE"
    fi

    # Process SAM file to extract unmapped fragments using the Python script
    for STRAND in forward revcom; do
        SAM_FILE="${OUTPUT_DIR}/${BASENAME}_${STRAND}.sam"
        if [ -s "${SAM_FILE}" ]; then  # Only process if the SAM file is non-empty
            echo "Processing ${SAM_FILE} to extract alignment positions" >> "$LOG_FILE"

            # Extract alignment start and end positions from the SAM file.
            # $1 !~ /^@/: Skips header lines.
            # $2 == 0: Selects primary alignments (unmapped reads have $2 != 0).
            # $4: Query start position.
            # length($10): Length of the query sequence.
            awk '$1 !~ /^@/ && $2 == 0 {print $4 "\t" length($10)}' "${SAM_FILE}" > "${OUTPUT_DIR}/${BASENAME}_${STRAND}_alignments.txt" 2>> "$LOG_FILE"
            
            # Run Python script to extract unaligned fragments (flanking regions).
            echo "Running Python script for ${BASENAME} ${STRAND}" >> "$LOG_FILE"
            python3.12 /path/to/extract_unaligned_fragments.py \
                --input "${SEQ_B}" \
                --alignments "${OUTPUT_DIR}/${BASENAME}_${STRAND}_alignments.txt" \
                --output "${OUTPUT_DIR}/${BASENAME}_${STRAND}_unaligned.fasta" 2>> "${OUTPUT_DIR}/${BASENAME}_${STRAND}_python.log"
            
            if [ $? -eq 0 ]; then
                touch "${OUTPUT_DIR}/${BASENAME}_${STRAND}_python_complete.flag"
                echo "Python script completed for ${BASENAME} ${STRAND}" >> "$LOG_FILE"
            else
                echo "Error in Python script for ${BASENAME} ${STRAND}" >> "$LOG_FILE"
            fi
        else
            echo "No alignment found in ${SAM_FILE}, skipping ${STRAND} processing for ${BASENAME}." >> "$LOG_FILE"
        fi
    done
done

echo "Flanking region extraction workflow completed." >> "$LOG_FILE"

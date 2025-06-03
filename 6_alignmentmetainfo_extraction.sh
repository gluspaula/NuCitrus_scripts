#!/bin/bash
#SBATCH --job-name=extract_aligned_seq_all
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=email@ufl.edu
#SBATCH --ntasks=1
#SBATCH --mem=XXgb
#SBATCH --nodes=1
#SBATCH --cpus-per-task=XX
#SBATCH --time=1-00:00:00
#SBATCH --output=extract_aligned_seq_all_%j.log
#SBATCH --account=group
#SBATCH --qos=group-b

# Load samtools module
module load samtools

# Main directory path
MAIN_DIR="/path/to/AtNPR1citrus_seq"

# Define input and output directories
SEQ_C="${MAIN_DIR}/references/GCF_022201045.2/GCF_022201045.2_Citrus_sinensis_v2.0_genomic.fna"
SAM_DIR="${MAIN_DIR}/mapped_to_reference/"
OUTPUT_DIR="${MAIN_DIR}/aligned_sequences_extracted/"

# Create output directory if it doesn't exist
mkdir -p "${OUTPUT_DIR}"

# Create log file
LOG_FILE="${OUTPUT_DIR}/aligned_sequences_run_all.log"
touch "$LOG_FILE"

# Function to calculate the aligned length from the CIGAR string
function cigar_length() {
    local cigar=$1
    local length=0

    # Parse the CIGAR string and sum up the matched bases (M)
    for num in $(echo "$cigar" | grep -o '[0-9]\+M'); do
        length=$((length + ${num%M}))
    done

    echo "$length"
}

# Loop through all SAM files with *_to_chr.sam in the filename
for SAM_FILE in "${SAM_DIR}"/*_to_chr.sam; do
    BASENAME=$(basename "${SAM_FILE}" "_to_chr.sam")

    echo "Processing ${SAM_FILE}" >> "$LOG_FILE"

    # Extract contig name, chromosome name, alignment start, and CIGAR string from the SAM file
    awk '$1 !~ /^@/ {print $1, $3, $4, $6}' "${SAM_FILE}" | while read contig chr start cigar; do
        # Calculate the alignment length based on the CIGAR string
        length=$(cigar_length "$cigar")
        end=$((start + length - 1))  # Adjust based on the actual length

        # Extract the aligned sequence from the reference genome using samtools
        samtools faidx "${SEQ_C}" "${chr}:${start}-${end}" >> "${OUTPUT_DIR}/${BASENAME}_aligned_sequences.fasta"

        # Add a header with the contig name, chromosome, and positions to the output FASTA file
        echo ">${contig}_${chr}_${start}_${end}" >> "${OUTPUT_DIR}/${BASENAME}_aligned_sequences.fasta"
        echo "Extracted aligned sequence for ${BASENAME}: ${contig}, ${chr}:${start}-${end}" >> "$LOG_FILE"
    done
done

echo "Aligned sequences extraction for all files completed." >> "$LOG_FILE"

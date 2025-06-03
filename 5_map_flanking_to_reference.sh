#!/bin/bash
# This script aligns the extracted T-DNA flanking regions to the Citrus sinensis
# reference genome to pinpoint the exact chromosome and precise coordinates of the
# T-DNA insertion, providing genetic localization.
# It is the fifth step in the NuCitrus_scripts workflow.

# Exit immediately if a command exits with a non-zero status.
# Treat unset variables as an error and exit.
# The exit status of a pipeline is the exit status of the last command that exited with a non-zero status,
# or zero if all commands exited successfully.
set -euo pipefail

# SLURM directives for job submission
#SBATCH --job-name=align_unmapped_to_C
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=email@ufl.edu
#SBATCH --ntasks=1
#SBATCH --mem=XXgb # Placeholder for memory
#SBATCH --nodes=1
#SBATCH --cpus-per-task=XX # Placeholder for CPUs
#SBATCH --time=1-00:00:00
#SBATCH --output=align_unmapped_to_chr_%j.log
#SBATCH --account=group
#SBATCH --qos=group-b

# Load necessary modules
module load minimap2 

# Main directory path (consistent with previous scripts)
MAIN_DIR="/path/to/AtNPR1citrus_seq" # Placeholder: Update to your actual base data path

# Define input and output directories
# SEQ_C: Path to the Citrus sinensis reference genome.
SEQ_C="${MAIN_DIR}/references/GCF_022201045.2/GCF_022201045.2_Citrus_sinensis_v2.0_genomic.fna" # Placeholder: Update to your actual reference path
# UNMAPPED_DIR: Input directory for unaligned fragments (output from 4_extract_flanking_regions.sh).
UNMAPPED_DIR="${MAIN_DIR}/unmapped_fragments/"
# OUTPUT_DIR: Output directory for alignment results to the reference chromosome.
OUTPUT_DIR="${MAIN_DIR}/mapped_to_reference/"

# Create output directory if it doesn't exist
mkdir -p "${OUTPUT_DIR}"

# Create log file for the script
LOG_FILE="${OUTPUT_DIR}/alignment_to_chr_run.log"
touch "$LOG_FILE"

echo "Starting alignment of unmapped fragments to reference genome." >> "$LOG_FILE"
echo "Reference genome (Sequence C): $SEQ_C" >> "$LOG_FILE"
echo "Input unmapped fragments directory: $UNMAPPED_DIR" >> "$LOG_FILE"
echo "Output alignments directory: $OUTPUT_DIR" >> "$LOG_FILE"

# Loop through each unaligned fragment file (FASTA format)
for UNMAPPED in "${UNMAPPED_DIR}"/*.fasta; do
    BASENAME=$(basename "${UNMAPPED}" .fasta)

    echo "Processing ${BASENAME} - Aligning to Reference Genome (Sequence C)" >> "$LOG_FILE"

    # Align the unaligned fragments to Sequence C (the reference genome).
    # minimap2 -a: Outputs in SAM format.
    # The output SAM file is redirected to a unique file for each sample.
    minimap2 -a "${SEQ_C}" "${UNMAPPED}" > "${OUTPUT_DIR}/${BASENAME}_to_chr.sam" 2>> "$LOG_FILE"
    
    # Check the exit status of the minimap2 command.
    if [ $? -eq 0 ]; then
        # Create a flag file to indicate successful completion for this sample.
        touch "${OUTPUT_DIR}/${BASENAME}_to_chr_complete.flag"
        echo "Alignment completed for ${BASENAME} to Reference Genome." >> "$LOG_FILE"
    else
        echo "Error in alignment for ${BASENAME} to Reference Genome. Check logs for details." >> "$LOG_FILE"
    fi
done

echo "Alignment of all unaligned fragments to Reference Genome completed." >> "$LOG_FILE"

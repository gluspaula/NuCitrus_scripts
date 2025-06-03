#!/bin/bash
#SBATCH --job-name=filtlong_flye_quast_qc15
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=email@ufl.edu
#SBATCH --ntasks=1
#SBATCH --mem=XXgb
#SBATCH --nodes=1
#SBATCH --cpus-per-task=XX
#SBATCH --time=48:00:00
#SBATCH --output=filtlong_flye_quast_qc15_%j.log
#SBATCH --error=filtlong_flye_quast_qc15_%j.err
#SBATCH --account=group
#SBATCH --qos=group-b

# List of samples (transgenic lines) to process.
samples=(
    "T13-3A" "T13-3merge" "T13-3B"
    "T24A" "T24B" "T24merge"
    "T26A" "T26B" "T26merge"
    "T35A" "T35B" "T35merge" "T35HMW"
    "T57-25A" "T57-25B" "T57-25merge"
    "T69A" "T69B" "T69merge"
)

# Main directory path (consistent with 1_concat.sh)
MAIN_DIR="/path/to/AtNPR1citrus_seq" # Placeholder: Update to your actual base data path

# Input directory for the concatenated FASTQ files (output from 1_concat.sh).
INPUT_DIR="${MAIN_DIR}/all_raw_qc10" # Consistent with 1_concat.sh output

# Output directory for assembled genomes by Flye.
OUTPUT_DIR="${MAIN_DIR}/assemblies_qc15" # Consistent with README.md

# Output directory for QUAST quality assessment reports.
QUAST_OUTPUT_DIR="${MAIN_DIR}/quast_reports_qc15" # Consistent with README.md

# Path to the reference genome for QUAST.
REFERENCE="${MAIN_DIR}/references/GCF_022201045.2/GCF_022201045.2_Citrus_sinensis_v2.0_genomic.fna" # Placeholder: Update to your actual reference path

# Ensure the output directories exist.
mkdir -p "$OUTPUT_DIR"
mkdir -p "$QUAST_OUTPUT_DIR"

# Load necessary modules for the tools used in this script.
module load filtlong
module load flye
module load quast

echo "Starting assembly workflow."
echo "Input reads directory: $INPUT_DIR"
echo "Assemblies output directory: $OUTPUT_DIR"
echo "QUAST reports output directory: $QUAST_OUTPUT_DIR"
echo "Reference genome for QUAST: $REFERENCE"

# Loop through each sample, run Filtlong, Flye, and QUAST.
for sample in "${samples[@]}"; do
    echo "--- Processing sample: $sample ---"

    # Define the path to the input concatenated and gzipped FASTQ file for the current sample.
    # This path is consistent with the output naming from 1_concat.sh
    INPUT_FILE="${INPUT_DIR}/${sample}_all_raw.qc10.fastq.gz"
    
    # Define the path for the output filtered reads from Filtlong.
    OUTPUT_FILTERED_READS="$OUTPUT_DIR/${sample}_filtered_qc15.fastq.gz"

    # Check if input file exists
    if [ -f "$INPUT_FILE" ]; then
        echo "Found input file: '$INPUT_FILE'"
        
        # Step 1: Run Filtlong with Phred score filtering to qc15 and gzip the output
        filtlong --min_mean_q 15 "$INPUT_FILE" | gzip > "$OUTPUT_FILTERED_READS"
        echo "$sample filtering complete. Output saved to $OUTPUT_FILTERED_READS"
        
        # Step 2: Run Flye assembly using the filtered reads
        echo "Running Flye assembly for $sample..."
        FLYE_OUT_DIR="$OUTPUT_DIR/${sample}_assembly"
        mkdir -p "$FLYE_OUT_DIR"
        flye --nano-hq "$OUTPUT_FILTERED_READS" \
             --out-dir "$FLYE_OUT_DIR" \
             --asm-coverage 60 \
             --genome-size 370m \
             --threads XX
        echo "Flye assembly for '$sample' complete. Output saved to '$FLYE_OUT_DIR'."
        
        # Step 3: Run QUAST on the newly generated assembly
        echo "Running QUAST for $sample..."
        QUAST_ASSEMBLY="$FLYE_OUT_DIR/assembly.fasta"
        QUAST_SAMPLE_OUT="$QUAST_OUTPUT_DIR/${sample}_quast_report"
        
        if [ -f "$QUAST_ASSEMBLY" ]; then
            mkdir -p "$QUAST_SAMPLE_OUT"
            quast "$QUAST_ASSEMBLY" \
                  -R "$REFERENCE" \
                  --fast \
                  -o "$QUAST_SAMPLE_OUT"
            echo "QUAST analysis for '$sample' complete. Output saved to '$QUAST_SAMPLE_OUT'."
        else
            echo "Warning: Assembly file '$QUAST_ASSEMBLY' not found for '$sample'. Skipping QUAST."
        fi
        
    else
        echo "Warning: Input file '$INPUT_FILE' not found for sample '$sample'. Skipping processing for this sample."
    fi
done

echo "Assembly workflow completed."

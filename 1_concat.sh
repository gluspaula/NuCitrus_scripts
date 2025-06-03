#!/bin/bash
# This script concatenates raw Nanopore .fastq.gz files from various subdirectories
# into single gzipped FASTQ files for each specified transgenic line.
# It is the first step in the NuCitrus_scripts workflow, preparing data for assembly.

# Exit immediately if a command exits with a non-zero status.
# Treat unset variables as an error and exit.
# The exit status of a pipeline is the exit status of the last command that exited with a non-zero status,
# or zero if all commands exited successfully.
set -euo pipefail

# SLURM directives for job submission
#SBATCH --job-name=concatncompress
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=email@ufl.edu # Replace with your email
#SBATCH --ntasks=1
#SBATCH --mem=XXgb
#SBATCH --nodes=1
#SBATCH --cpus-per-task=XX  # XX CPUs allocated for pigz for parallel compression
#SBATCH --time=24:00:00
#SBATCH --output=concatncompress_%j.log
#SBATCH --error=concatncompress_%j.err
#SBATCH --account=group # Replace with your SLURM account
#SBATCH --qos=group-b # Replace with your SLURM QOS

# Load required modules
# These modules provide necessary tools like zcat and pigz.
module load gcc/5.2.0  # Load the GCC module first, often a dependency
module load pigz/2.4   # Load pigz module for parallel gzip

# Main directory path where raw sequencing data is located.
# This is a placeholder. Users should replace "/path/to/AtNPR1citrus_seq"
# with the actual absolute path to their data.
MAIN_DIR="/path/to/AtNPR1citrus_seq"

# List of directories (transgenic lines) to process.
# Each of these directories is expected to contain a 'fastq_pass' subdirectory.
directories=("T13-3A" "T13-3B" "T24A" "T26A" "T26B" "T35A" "T35B" "T35HMW" "T57-25A" "T57-25B" "T69A" "T69B")

# Output directory for the concatenated and compressed FASTQ files.
# This directory will be created within the MAIN_DIR.
OUTPUT_DIR="${MAIN_DIR}/all_raw_qc10"

# Create the output directory if it doesn't exist.
# The -p flag ensures parent directories are also created if they don't exist.
mkdir -p "$OUTPUT_DIR"

echo "Starting concatenation and compression process."
echo "Main data directory: $MAIN_DIR"
echo "Output directory: $OUTPUT_DIR"

# Loop through each specified directory (transgenic line).
for dir in "${directories[@]}"; do
    echo "--- Processing directory: $dir ---"
    
    # Define the full path to the 'fastq_pass' subdirectory for the current line.
    FASTQ_PASS_DIR="${MAIN_DIR}/${dir}/fastq_pass"
    
    # Define the full path for the final concatenated and compressed output file.
    OUTPUT_FILE="${OUTPUT_DIR}/${dir}_all_raw.qc10.fastq.gz"
    
    # Check if the output file already exists.
    # If it does, skip processing for this directory to avoid overwriting and save time.
    if [ -f "$OUTPUT_FILE" ]; then
        echo "Output file '$OUTPUT_FILE' already exists. Skipping processing for '$dir'."
        continue
    fi
    
    # Check if the 'fastq_pass' directory exists for the current line.
    if [ -d "$FASTQ_PASS_DIR" ]; then
        echo "Found data directory: '$FASTQ_PASS_DIR'"
        
        # Find all .fastq.gz files within the 'fastq_pass' directory.
        # The array 'fastq_files' will store the paths to these files.
        fastq_files=( "$FASTQ_PASS_DIR"/*.fastq.gz )
        
        # Check if any .fastq.gz files were found.
        # If no files are found, print a message and move to the next directory.
        if [ "${#fastq_files[@]}" -eq 0 ]; then
            echo "No .fastq.gz files found in '$FASTQ_PASS_DIR'. Skipping to next directory."
            continue
        fi
        
        # Concatenate and compress the files directly using a pipe.
        # 'zcat' decompresses and concatenates all specified gzipped files.
        # The output is piped to 'pigz -p XX', which compresses it in parallel using XX CPU cores.
        # The final compressed output is redirected to the '$OUTPUT_FILE'.
        echo "Concatenating and compressing files from '$FASTQ_PASS_DIR' to '$OUTPUT_FILE' using pigz."
        if zcat "${fastq_files[@]}" | pigz -p XX > "$OUTPUT_FILE"; then
            echo "Successfully concatenated and compressed '$OUTPUT_FILE'."
        else
            # If the zcat or pigz command fails, print an error and skip to the next directory.
            echo "Error during concatenation and compression for '$dir'. Skipping to next directory."
            continue
        fi
        
    else
        # If the 'fastq_pass' directory does not exist, print a warning and skip.
        echo "Directory '$FASTQ_PASS_DIR' does not exist. Skipping to next directory."
    fi
done

# Special handling for T35-repeats (RT35A, RT35B, RT35C subdirectories).
# This section processes a specific set of subdirectories that might have a different naming convention
# or require separate handling.
echo "--- Starting special handling for T35-repeats ---"
T35_REPEATS_DIR="${MAIN_DIR}/T35-repeats"
for subdir in "RT35A" "RT35B" "RT35C"; do
    # Define the full path to the 'fastq_pass' subdirectory within the T35-repeats structure.
    FASTQ_PASS_SUBDIR="${T35_REPEATS_DIR}/${subdir}/fastq_pass"
    
    echo "Processing subdirectory: $subdir"
    
    # Define the full path for the output file for these special subdirectories.
    OUTPUT_FILE_REPEATS="${OUTPUT_DIR}/T35-repeats_${subdir}_all_raw.qc10.fastq.gz"
    
    # Skip if the output file already exists.
    if [ -f "$OUTPUT_FILE_REPEATS" ]; then
        echo "File '$OUTPUT_FILE_REPEATS' already exists. Skipping processing for '$subdir'."
        continue
    fi
    
    # Check if the 'fastq_pass' subdirectory exists.
    if [ -d "$FASTQ_PASS_SUBDIR" ]; then
        echo "Found data subdirectory: '$FASTQ_PASS_SUBDIR'"
        
        # Find all .fastq.gz files within this subdirectory.
        fastq_files=( "$FASTQ_PASS_SUBDIR"/*.fastq.gz )
        
        # Check if any .fastq.gz files were found.
        if [ "${#fastq_files[@]}" -eq 0 ]; then
            echo "No .fastq.gz files found in '$FASTQ_PASS_SUBDIR'. Skipping to next subdirectory."
            continue
        fi
        
        # Concatenate and compress directly using a pipe.
        echo "Concatenating and compressing files from '$FASTQ_PASS_SUBDIR' to '$OUTPUT_FILE_REPEATS' using pigz."
        if zcat "${fastq_files[@]}" | pigz -p XX > "$OUTPUT_FILE_REPEATS"; then
            echo "Successfully concatenated and compressed '$OUTPUT_FILE_REPEATS'."
        else
            echo "Error during concatenation and compression for 'T35-repeats_${subdir}'. Skipping to next subdirectory."
            continue
        fi
        
    else
        echo "Subdirectory '$FASTQ_PASS_SUBDIR' does not exist. Skipping to next subdirectory."
    fi
done

echo "Concatenation and compression process completed."

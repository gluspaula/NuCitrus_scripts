#!/bin/bash
#SBATCH --job-name=extract_headers
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=email@ufl.edu
#SBATCH --ntasks=1
#SBATCH --mem=XXgb
#SBATCH --nodes=1
#SBATCH --cpus-per-task=XX
#SBATCH --time=01:00:00
#SBATCH --output=extract_headers_%j.log
#SBATCH --account=group
#SBATCH --qos=group-b

# Main directory path (consistent with previous scripts)
MAIN_DIR="/path/to/AtNPR1citrus_seq"

# Define the directory where the FASTA files (output from step 6) are located
FASTA_DIR="${MAIN_DIR}/aligned_sequences_extracted/"
OUTPUT_CSV="${MAIN_DIR}/alignment_csv_reports/aligned_headers.csv" # Path to the output CSV file

# Create or overwrite the output CSV file
echo "File Name,Header Line" > "$OUTPUT_CSV"

# Loop through all FASTA files in the specified directory
for fasta_file in "${FASTA_DIR}"/*.fasta; do
    # Extract the file name
    fasta_name=$(basename "$fasta_file")

    # Search for lines starting with ">" and append to the CSV
    grep "^>" "$fasta_file" | while read -r header_line; do
        echo "${fasta_name},${header_line}" >> "$OUTPUT_CSV"
    done
done

echo "Finished extracting headers into $OUTPUT_CSV"

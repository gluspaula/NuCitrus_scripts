#!/bin/bash
#SBATCH --job-name=minimap_loop
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=email@ufl.edu
#SBATCH --ntasks=1
#SBATCH --mem=XXgb # Placeholder for memory
#SBATCH --nodes=1
#SBATCH --cpus-per-task=XX # Placeholder for CPUs
#SBATCH --time=2-00:00:00
#SBATCH --output=minimap_loop_%j.log
#SBATCH --account=group
#SBATCH --qos=group-b

# Load necessary modules
module load minimap2 samtools

# Number of threads to use
THREADS=XX # Placeholder for threads

# Main directory path (consistent with previous scripts)
MAIN_DIR="/path/to/AtNPR1citrus_seq" # Placeholder: Update to your actual base data path

# Target sequence and directories
TARGET_SEQ="${MAIN_DIR}/references/TDNAsequences/AtNPR1seq_fixed.fa" # Placeholder for TDNA sequence path
ASSEMBLY_DIR="${MAIN_DIR}/assemblies_qc15" # Input directory for assembled contigs (output from 2_assemble.sh)
OUTPUT_DIR="${MAIN_DIR}/AtNPR1_genomelocation_qc15_fixedAtNPR1" # Output directory for contig mapping to TDNA sequence

# Ensure output directories exist
mkdir -p "$OUTPUT_DIR"

# Function to check if a step succeeded, but continue if a step fails
check_exit_status_continue() {
    if [ $? -ne 0 ]; then
        echo "Warning: $1 failed, but continuing."
    fi
}

# List of samples
samples=(
    "T69B" "T35merged" "T26merged" "T24merged" "T13-3merged"
    "T69A" "T57-25B" "T57-25A" 
    "T35-repeats_RT35C" "T35-repeats_RT35B" "T35-repeats_RT35A" 
    "T35HMW" "T35B" "T35A" "T26B" "T26A" 
    "T24B" "T24A" "T13-3B" "T13-3A" 
    "T57-25merged" "T69merged"
)

# Loop through each sample and run minimap2
for sample in "${samples[@]}"; do
    echo "Processing $sample..."

    # Define input and output files
    ASSEMBLY="$ASSEMBLY_DIR/${sample}_assembly/assembly.fasta"
    MAPPED_BAM="$OUTPUT_DIR/mapped_${sample}.bam"
    FINAL_SAM="$OUTPUT_DIR/mapped_${sample}.sam"
    CONTIGS_FASTA="$OUTPUT_DIR/contigs_mapped_${sample}.fasta"
    MINIMAP_FLAG="$OUTPUT_DIR/${sample}_minimap_completed.flag"

    # Run minimap2 if not already done
    if [ ! -f "$MINIMAP_FLAG" ]; then
        # Align assembled contigs to the T-DNA sequence using minimap2.
        # -ax map-ont: Preset for Oxford Nanopore reads to long reference sequences.
        # -t XX: Number of threads.
        # samtools view -Sb -F 4 -@ XX: Converts SAM to BAM, filters out unmapped reads, uses XX threads.
        minimap2 -ax map-ont -t $THREADS "$ASSEMBLY" "$TARGET_SEQ" | samtools view -Sb -F 4 -@ $THREADS - > "$MAPPED_BAM"
        check_exit_status_continue "minimap2 for $sample"
        
        # Convert BAM back to SAM using multiple threads
        samtools view -h -@ $THREADS "$MAPPED_BAM" > "$FINAL_SAM"
        check_exit_status_continue "samtools view for $sample"
        
        # Extract contig names that mapped to the T-DNA sequence.
        # Filters out header lines, takes the 3rd column (contig name), sorts, and gets unique names.
        samtools view "$MAPPED_BAM" | grep -v '^@' | cut -f 3 | sort | uniq > "$OUTPUT_DIR/${sample}_contig_names.txt"
        check_exit_status_continue "Extract contig names for $sample"

        # Use samtools faidx to extract the full sequences of the mapped contigs.
        # This creates a FASTA file containing only the contigs that aligned to the T-DNA.
        xargs samtools faidx "$ASSEMBLY" < "$OUTPUT_DIR/${sample}_contig_names.txt" > "$CONTIGS_FASTA"
        check_exit_status_continue "samtools faidx for $sample"

        # Create a flag file to indicate that minimap processing for this sample is complete.
        touch "$MINIMAP_FLAG"
        echo "$sample minimap processing complete."
    else
        echo "$sample minimap already processed. Skipping minimap step."
    fi
done

echo "All samples processed."

import argparse
from Bio import SeqIO

def parse_args():
    """
    Parses command-line arguments for the script.
    --input: Path to the input FASTA file (Sequence B, i.e., assembled contigs).
    --alignments: Path to the file containing alignment start/end positions.
    --output: Path to the output FASTA file where unaligned fragments will be saved.
    """
    parser = argparse.ArgumentParser(description="Extract unaligned fragments from sequence B")
    parser.add_argument("--input", required=True, help="Input FASTA file (Sequence B)")
    parser.add_argument("--alignments", required=True, help="File with alignment start/end positions")
    parser.add_argument("--output", required=True, help="Output FASTA file for unaligned fragments")
    return parser.parse_args()

def extract_unaligned_fragments(seq_b_fasta_path, alignments_file_path, output_fasta_path):
    """
    Reads Sequence B, and an alignment file, then extracts and writes
    unaligned (flanking) fragments to an output FASTA file.

    Args:
        seq_b_fasta_path (str): Path to the input FASTA file (Sequence B).
        alignments_file_path (str): Path to the file with alignment start/end positions.
        output_fasta_path (str): Path to the output FASTA file for unaligned fragments.
    """
    # Open the output FASTA file in write mode.
    with open(output_fasta_path, "w") as out_fasta:
        # Open a log file specific to the Python script in append mode.
        with open("python_script.log", "a") as log_file:
            log_file.write(f"Processing {seq_b_fasta_path}\n")
            
            # Parse the alignment file to get the start and end positions of alignments.
            # This file is expected to contain lines with two space-separated integers:
            # <start_position_of_alignment> <length_of_aligned_segment>
            with open(alignments_file_path) as align_file:
                for line in align_file:
                    line = line.strip()
                    if not line:
                        continue  # Skip empty lines

                    try:
                        # Split the line to get start position and aligned length.
                        start_pos, aligned_len = map(int, line.split())
                        # Calculate the end position of the aligned segment.
                        end_pos = start_pos + aligned_len - 1
                        log_file.write(f"Alignment: start={start_pos}, length={aligned_len}, end={end_pos}\n")
                    except ValueError:
                        # Log an error if a line cannot be parsed as integers.
                        log_file.write(f"Skipping invalid line: {line}\n")
                        continue

                    # Read Sequence B (the contig) and extract unaligned fragments.
                    # SeqIO.parse is used to handle FASTA files, even if they contain multiple records.
                    for record in SeqIO.parse(seq_b_fasta_path, "fasta"):
                        seq_len = len(record.seq)

                        # Extract the left fragment: from the beginning of the sequence to (start_pos - 1).
                        # This fragment is considered unaligned if the alignment does not start at position 1.
                        if start_pos > 1:
                            left_fragment = record.seq[:start_pos - 1]
                            out_fasta.write(f">{record.id}_left\n{left_fragment}\n")
                            log_file.write(f"Left fragment extracted: {record.id}_left\n")

                        # Extract the right fragment: from (end_pos + 1) to the end of the sequence.
                        # This fragment is considered unaligned if the alignment does not extend to the end of the sequence.
                        if end_pos < seq_len:
                            right_fragment = record.seq[end_pos:] # Corrected slice: end_pos is 0-indexed, so it's the character *after* the alignment.
                            out_fasta.write(f">{record.id}_right\n{right_fragment}\n")
                            log_file.write(f"Right fragment extracted: {record.id}_right\n")

def main():
    """
    Main function to parse arguments and call the fragment extraction function.
    """
    args = parse_args()
    extract_unaligned_fragments(args.input, args.alignments, args.output)

if __name__ == "__main__":
    main()

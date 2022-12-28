#!/bin/bash
#SBATCH --partition=norm
#SBATCH --cpus-per-task=32
#SBATCH --mem=232g
#SBATCH --ntasks-per-core=1
#SBATCH --time=30:00:00
#SBATCH --mail-type=FAIL,END
#SBATCH --mail-user=javan.okendo@nih.gov

cd /data/okendojo/paradisfishProject/RNA_seq_data/transcriptome_files/braker

INPUT_FASTA=/data/okendojo/paradisfishProject/RNA_seq_data/transcriptome_files/asmTranstrinity.Trinity.fasta
GFACS_OUTPUT_PFX="gfacsTmp"
GFACS_OUTPUT_DIR=/data/okendojo/paradisfishProject/RNA_seq_data/transcriptome_files/braker/gFACs_result
INPUT_GFF=/data/okendojo/paradisfishProject/RNA_seq_data/transcriptome_files/braker/braker.gtf

gFACs.pl \
	-f "braker_2.1.5_gtf" \
	-p "${GFACS_OUTPUT_PFX}" \
	--statistics-at-every-step \
	--statistics \
	--rem-monoexonics \
	--min-exon-size 20 \
	--min-intron-size 20 \
	--min-CDS-size 74 \
	--fasta "${INPUT_FASTA}" \
	--splice-table \
	--nt-content \
	--canonical-only \
	--rem-genes-without-stop-codon \
	--allowed-inframe-stop-codons 0 \
	--create-gff3 \
	--get-fasta-with-introns \
	--get-fasta-without-introns \
	--get-protein-fasta \
	--distributions \
		exon_lengths \
		intron_lengths \
		CDS_lengths \
		gene_lengths \
		exon_position \
		exon_position_data \
		intron_position \
		intron_position_data \
	-O "${GFACS_OUTPUT_DIR}" \
	"${INPUT_GFF}"

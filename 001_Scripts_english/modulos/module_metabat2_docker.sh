#!/bin/bash
set -euo pipefail

# module_metabat2_docker.sh
# Args: sample contigs_fa bam_file out_dir threads docker_image min_contig_len

sample="$1"
contigs_fa="$2"
bam_file="$3"
out_dir="$4"
threads="$5"
docker_img="${6:-metabat/metabat:latest}"
min_len="${7:-2000}"

mkdir -p "$out_dir"

if [[ ! -s "$contigs_fa" ]]; then
  echo "[metabat2_docker] Contigs not found: $contigs_fa" >&2
  exit 1
fi
if [[ ! -s "$bam_file" ]]; then
  echo "[metabat2_docker] BAM not found: $bam_file" >&2
  exit 1
fi

echo "[metabat2_docker] Using Docker image $docker_img"

# We will run jgi_summarize_bam_contig_depths and metabat inside the container.
# Mount contigs and bam parent dirs and out_dir
contigs_dir=$(dirname "$contigs_fa")
bam_dir=$(dirname "$bam_file")
contig_name=$(basename "$contigs_fa")
bam_name=$(basename "$bam_file")

echo "[metabat2_docker] Generating depth file for $sample"
docker run --rm -v "$contigs_dir":/contigs -v "$bam_dir":/bams -v "$out_dir":/out "$docker_img" \
  jgi_summarize_bam_contig_depths --referenceFasta /contigs/${contig_name} --outputDepth /out/${sample}.depth /bams/${bam_name}

echo "[metabat2_docker] Running metabat2 with --minContig ${min_len}"
docker run --rm -v "$contigs_dir":/contigs -v "$out_dir":/out "$docker_img" \
  metabat -i /contigs/${contig_name} -a /out/${sample}.depth -o /out/${sample}.bin -t ${threads} -m ${min_len}

echo "[metabat2_docker] MetaBat2 output in $out_dir"

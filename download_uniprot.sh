#!/bin/sh
source ./paths.sh

mkdir -p "uniprot/${RELEASE}"

wget ftp://ftp.expasy.org/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.fasta.gz -O uniprot/${RELEASE}/uniprot_sprot.fasta.gz 
wget ftp://ftp.expasy.org/databases/uniprot/current_release/knowledgebase/complete/uniprot_trembl.fasta.gz -O uniprot/${RELEASE}/uniprot_trembl.fasta.gz 

zcat uniprot/${RELEASE}/uniprot_sprot.fasta.gz uniprot/${RELEASE}/uniprot_trembl.fasta.gz > uniprot/${RELEASE}/uniprot_sprot_trembl.fasta

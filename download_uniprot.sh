#!/bin/sh
source ./paths.sh

mkdir -p "uniprot/${RELEASE}"

echo "Please insert the base url for the chosen release below and comment this line and the next."
exit 1

wget ftp://ftp.expasy.org/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.fasta.gz -O uniprot/${RELEASE}/uniprot_sprot.fasta.gz 
wget ftp://ftp.expasy.org/databases/uniprot/current_release/knowledgebase/complete/uniprot_trembl.fasta.gz -O uniprot/${RELEASE}/uniprot_trembl.fasta.gz 

zcat uniprot/${RELEASE}/uniprot_sprot.fasta.gz uniprot/${RELEASE}/uniprot_trembl.fasta.gz > uniprot/${RELEASE}/uniprot_sprot_trembl.fasta

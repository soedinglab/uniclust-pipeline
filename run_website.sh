#!/bin/bash -ex
#BSUB -q mpi-long+
#BSUB -o log-website.%J
#BSUB -e log-website.%J
#BSUB -W 120:00
#BSUB -n 16
#BSUB -a openmpi
#BSUB -m hh
#BSUB -R haswell
#BSUB -R cbscratch
#BSUB -R "span[ptile=16]"

source paths-latest.sh

WEBTARGET="${UNICLUSTWEB}/${RELEASE}"
mkdir -m 750 -p ${WEBTARGET}

awk '{ gsub(/_[[:digit:]]*/, "", $2); print $1"\t"$2; }' "${TARGET}/uniprot_db.lookup" > "/local/uniprot_db.lookup_nosplit"
for i in 30 50 90; do
    mmseqs filterdb "${TARGET}/uniclust${i}_${RELEASE}" "/local/uniclust${i}_${RELEASE}_AC" --mapping-file "/local/uniprot_db.lookup_nosplit"
done

rm -f "/local/uniprot_db.lookup_nosplit"

for i in pdb scop pfam ; do
    LC_ALL=C sort -S60G --parallel=16 --temporary-directory=/dev/shm ${TARGET}/tmp/update/30/annotation/uniclust30_${RELEASE}_${i}.tsv > /local/uniclust30_${RELEASE}_${i}.tsv_sorted
    gawk -f ffindex.awk -v outfile=/local/uniclust_${RELEASE}_domains_${i} /local/uniclust30_${RELEASE}_${i}.tsv_sorted
    rm -f /local/uniclust30_${RELEASE}_${i}.tsv /local/uniclust30_${RELEASE}_${i}.tsv_sorted
done

mmseqs convertkb ${UNIPROTBASE}/uniprot_sprot_trembl.dat.gz /local/uniprotkb_${RELEASE} --kb-columns "8,13,14"
for i in KW PE OX; do
    join -o 1.2,2.2,2.3 -t $'\t' /local/uniprotkb_${RELEASE}.lookup /local/uniprotkb_${RELEASE}_${i}.index > /local/uniprotkb_${RELEASE}_${i}.index_mapped
    mv -f /local/uniprotkb_${RELEASE}_${i}.index_mapped /local/uniprotkb_${RELEASE}_${i}.index
    ffindex_build -as /local/uniprotkb_${RELEASE}_${i} /local/uniprotkb_${RELEASE}_${i}.index
done

cp ${TARGET}/uniclust{30,50,90}_${RELEASE}{,.index} ${WEBTARGET}
cp ${TARGET}/uniclust{30,50,90}_${RELEASE}_a3m.ff{data,index} ${WEBTARGET}

mv /local/uniprotkb_${RELEASE}_{PE,KW,OX}{,.index} ${WEBTARGET}
mv /local/uniclust_${RELEASE}_domains_{pdb,pfam,scop}{,.index} ${WEBTARGET}
mv /local/uniclust{30,50,90}_${RELEASE}_AC{,.index} "${WEBTARGET}"

chmod 644 ${WEBTARGET}/uniclust{30,50,90}_${RELEASE}{,_AC}{,.index} ${WEBTARGET}/uniclust{30,50,90}_${RELEASE}_a3m.ff{data,index} ${WEBTARGET}/uniprotkb_${RELEASE}_{PE,KW,OX}{,.index} ${WEBTARGET}/uniclust_${RELEASE}_domains_{pdb,pfam,scop}{,.index}

#!/bin/bash -ex
#BSUB -q mpi-long+
#BSUB -o out.%J
#BSUB -e err.%J
#BSUB -W 330:00
#BSUB -n 64
#BSUB -a openmpi
#BSUB -m hh
#BSUB -R haswell
#BSUB -R cbscratch
#BSUB -R "span[ptile=16]"

#export RUNNER="mpicmd"
export OMP_NUM_THREADS=16

source hhdatabase/make_hhdatabase.sh
source uniclust/make_fasta.sh

function updatepaths() {
    local RELEASE;
    local SHORTRELEASE;
    local BASE;
    local FASTA;
    local TARGET;
    source $1;
    OLDRELEASE="$RELEASE";
    OLDSHORTRELEASE="$SHORTRELEASE";
    OLDBASE="$BASE";
    OLDFASTA="$FASTA";
    OLDTARGET="$TARGET";
    source $2;
    NEWRELEASE="$RELEASE";
    NEWSHORTRELEASE="$SHORTRELEASE";
    NEWBASE="$BASE";
    NEWFASTA="$FASTA";
    NEWTARGET="$TARGET";
}

updatepaths paths.sh paths-update.sh;

PREFILTER_COMMON=""
PREFILTER90_PAR="-c 0.9 -s 2 --start-sens 2 ${PREFILTER_COMMON}"
PREFILTER50_PAR="-c 0.8 -s 6 --start-sens 6 ${PREFILTER_COMMON}"
PREFILTER30_PAR="-c 0.8 -s 6 --start-sens 6 ${PREFILTER_COMMON}"
ALIGNMENT_COMMON="-e 0.001"
ALIGNMENT90_PAR="--alignment-mode 2 --min-seq-id 0.9 --comp-bias-corr 1 ${ALIGNMENT_COMMON}"
ALIGNMENT50_PAR="--alignment-mode 3 --min-seq-id 0.5 --comp-bias-corr 1 ${ALIGNMENT_COMMON}"
ALIGNMENT30_PAR="--alignment-mode 3 --min-seq-id 0.3 --comp-bias-corr 1 ${ALIGNMENT_COMMON}"
CLUSTER90_PAR="--cluster-mode 0"
CLUSTER50_PAR="--cluster-mode 0"
CLUSTER30_PAR="--cluster-mode 0"

COMMON="--recover-deleted --threads 16"
UPDATE90_PAR="${PREFILTER90_PAR} ${ALIGNMENT90_PAR} ${CLUSTER90_PAR} ${COMMON}"
UPDATE50_PAR="${PREFILTER50_PAR} ${ALIGNMENT50_PAR} ${CLUSTER50_PAR} ${COMMON}"
UPDATE30_PAR="${PREFILTER30_PAR} ${ALIGNMENT30_PAR} ${CLUSTER30_PAR} ${COMMON}"

mkdir -p "${NEWTARGET}/tmp/update"
# we split all sequences that are above 14k in N/14k parts
if [ ! -e "${NEWTARGET}/tmp/update/uniprot_db" ]; then
    mmseqs createdb "$NEWFASTA" "${NEWTARGET}/tmp/update/uniprot_db" --max-seq-len 14000
fi
if false; then
for i in 30 50 90 ; do
	date --rfc-3339=seconds
    UPDATE_PAR="UPDATE${i}_PAR"
    UPDATE_TMP="${NEWTARGET}/tmp/update/${i}"
    mkdir -p "${UPDATE_TMP}"
	mmseqs clusterupdate "${OLDTARGET}/uniprot_db" "${NEWTARGET}/tmp/update/uniprot_db" "${OLDTARGET}/uniclust${i}_${OLDRELEASE}" "${NEWTARGET}/uniclust${i}_${NEWRELEASE}" "${UPDATE_TMP}" ${!UPDATE_PAR}

    ln -sf "${UPDATE_TMP}/NEWDB" "${NEWTARGET}/uniprot_db"
    ln -sf "${UPDATE_TMP}/NEWDB.index" "${NEWTARGET}/uniprot_db.index"
    ln -sf "${UPDATE_TMP}/NEWDB_h" "${NEWTARGET}/uniprot_db_h"
    ln -sf "${UPDATE_TMP}/NEWDB_h.index" "${NEWTARGET}/uniprot_db_h.index"
    ln -sf "${UPDATE_TMP}/NEWDB.lookup" "${NEWTARGET}/uniprot_db.lookup"

    #LC_ALL=C comm -13 <(cut "${UPDATE_TMP}/updatedClust.index"  -f1 | LC_ALL=C sort) <(cut "${OLDTARGET}/uniclust${i}_${OLDRELEASE}.index" -f1 | LC_ALL=C sort) > "${UPDATE_TMP}/changedids"
    cut "${UPDATE_TMP}/newSeqsHits.swapped.index" -f1 > "${UPDATE_TMP}/changedids" 
    cut "${UPDATE_TMP}/newClusters.index" -f1 > "${UPDATE_TMP}/newids" 
    cat "${UPDATE_TMP}/changedids" "${UPDATE_TMP}/newids" > "${UPDATE_TMP}/changedandnew"

    mkdir -p "${UPDATE_TMP}/changed"
    mmseqs createsubdb "${UPDATE_TMP}/changedandnew" "${NEWTARGET}/uniclust${i}_${NEWRELEASE}" "${UPDATE_TMP}/changed/uniclust${i}_${NEWRELEASE}"

    mkdir -p "${UPDATE_TMP}/fasta"
    make_fasta "$i" "$NEWRELEASE" "$NEWSHORTRELEASE" "${NEWTARGET}/uniprot_db" "${UPDATE_TMP}/changed/uniclust${i}_${NEWRELEASE}" "${NEWTARGET}" "${UPDATE_TMP}/fasta"

done

UPDATE_TMP="${NEWTARGET}/tmp/update/30"
mkdir -p "${UPDATE_TMP}/clust"
make_hhdatabase "${UPDATE_TMP}/changed" ${NEWRELEASE} "uniclust30" "${NEWTARGET}/uniprot_db" "${NEWTARGET}/tmp/update/clust" 

for i in 50 90; do 
    UPDATE_TMP="${NEWTARGET}/tmp/update/${i}"
    make_a3m "${UPDATE_TMP}/changed" "${NEWRELEASE}" "uniclust${i}" "${NEWTARGET}/uniprot_db" "${UPDATE_TMP}/clust"
done
fi

UPDATE_TMP="${NEWTARGET}/tmp/update/30"
mkdir -p "${UPDATE_TMP}/annotation"
for type in pfam scop pdb; do
    ln -sf "${UPDATE_TMP}/clust/uniclust30_${NEWRELEASE}_a3m.ffdata" "${UPDATE_TMP}/clust/uniclust30_${NEWRELEASE}_a3m"
    ln -sf "${UPDATE_TMP}/clust/uniclust30_${NEWRELEASE}_a3m.ffindex" "${UPDATE_TMP}/clust/uniclust30_${NEWRELEASE}_a3m.index"
    
    $RUNNER mmseqs extractdomains "${OLDTARGET}/tmp/annotation/uniboost10_${OLDRELEASE}_${type}_annotation" "${UPDATE_TMP}/clust/uniclust30_${NEWRELEASE}_a3m" "${UPDATE_TMP}/annotation/uniclust30_${NEWRELEASE}_${type}" --msa-type 1 -e 0.01
done

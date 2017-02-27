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
source uniclust/make_annotate.sh

function merge_old_and_new () {
    local OLDIDS="$1"
    local OLDDB="$2"
    local NEWIDS="$3"
    local NEWDB="$4"
    local RESULT="$5"
    local TMPPATH="$(mktemp -d "${6:-/tmp}/merge.XXXXXX")"
    if [ $? -ne 0 ]; then
        echo "Can not create temp file, exiting..."
        exit 1
    fi

    DBNAME="$(basename $NEWDB)"

    if [ -s "$NEWIDS" ]; then
        mmseqs createsubdb "$OLDIDS" "$OLDDB" "${TMPPATH}/${DBNAME}_old"
        mmseqs createsubdb "$NEWIDS" "$NEWDB" "${TMPPATH}/${DBNAME}_new"

        mmseqs concatdbs "${TMPPATH}/${DBNAME}_old" "${TMPPATH}/${DBNAME}_new" "${RESULT}/${DBNAME}" --preserve-keys
    else
        mmseqs createsubdb "$OLDIDS" "$OLDDB" "${RESULT}/${DBNAME}"
    fi

    rm -rf "$TMPPATH"
}

function merge_old_and_new_legacy () {
    local OLDIDS="$1"
    local OLDDB="$2"
    local NEWIDS="$3"
    local NEWDB="$4"
    local RESULT="$5"
    local TMPPATH="$(mktemp -d "${6:-/tmp}/merge.XXXXXX")"
    if [ $? -ne 0 ]; then
        echo "Can not create temp file, exiting..."
        exit 1
    fi

    OLDDBNAME="$(basename $OLDDB)"
    DBNAME="$(basename $NEWDB)"
    ln -sf "${OLDDB}.ffdata" "${TMPPATH}/${OLDDBNAME}" 
    ln -sf "${OLDDB}.ffindex" "${TMPPATH}/${OLDDBNAME}.index" 
    if [ -s "$NEWIDS" ]; then
        ln -sf "${NEWDB}.ffdata" "${TMPPATH}/${DBNAME}" 
        ln -sf "${NEWDB}.ffindex" "${TMPPATH}/${DBNAME}.index" 
     
        mmseqs createsubdb "$OLDIDS" "${TMPPATH}/${OLDDBNAME}" "${TMPPATH}/${DBNAME}_old"
        mmseqs createsubdb "$NEWIDS" "${TMPPATH}/${DBNAME}" "${TMPPATH}/${DBNAME}_new"

        mmseqs concatdbs "${TMPPATH}/${DBNAME}_old" "${TMPPATH}/${DBNAME}_new" "${RESULT}/${DBNAME}" --preserve-keys

        mv -f "${RESULT}/${DBNAME}" "${RESULT}/${DBNAME}.ffdata"
        mv -f "${RESULT}/${DBNAME}.index" "${RESULT}/${DBNAME}.ffindex"
    else 
        mmseqs createsubdb "$OLDIDS" "${TMPPATH}/${OLDDBNAME}" "${TMPPATH}/${DBNAME}_old"

        mv -f "${TMPPATH}/${DBNAME}_old" "${RESULT}/${DBNAME}.ffdata"
        mv -f "${TMPPATH}/${DBNAME}_o.d.index" "${RESULT}/${DBNAME}.ffindex"

    fi
    rm -rf "$TMPPATH"
}


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

updatepaths paths.sh paths-update2.sh
#updatepaths paths-update.sh paths-update2.sh

BOOSTTARGET=${BOOSTTARGET:-$OLDTARGET}
BOOSTRELEASE=${BOOSTRELEASE:-$OLDRELEASE}

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

#if false; then
mkdir -p "${NEWTARGET}/tmp/update"
# we split all sequences that are above 14k in N/14k parts
if [ ! -e "${NEWTARGET}/tmp/update/uniprot_db" ]; then
    mmseqs createdb "$NEWFASTA" "${NEWTARGET}/tmp/update/uniprot_db" --max-seq-len 14000
fi
#for i in 30 ; do
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

    if [ -f "${UPDATE_TMP}/newSeqsHits.swapped.index" ]; then
        cut "${UPDATE_TMP}/newSeqsHits.swapped.index" -f1 > "${UPDATE_TMP}/changedids" 
    else
        touch "${UPDATE_TMP}/changedids"
    fi
    cut "${UPDATE_TMP}/newClusters.index" -f1 > "${UPDATE_TMP}/newids" 
    cat "${UPDATE_TMP}/changedids" "${UPDATE_TMP}/newids" > "${UPDATE_TMP}/changedandnew"

    LC_ALL=C comm -13 <(cat "${UPDATE_TMP}/changedandnew" | LC_ALL=C sort) <(cut "${OLDTARGET}/uniclust${i}_${OLDRELEASE}.index" -f1 | LC_ALL=C sort) \
        > "${UPDATE_TMP}/unchanged"
    mkdir -p "${UPDATE_TMP}/changed"
    mmseqs createsubdb "${UPDATE_TMP}/changedandnew" "${NEWTARGET}/uniclust${i}_${NEWRELEASE}" "${UPDATE_TMP}/changed/uniclust${i}_${NEWRELEASE}"


    mkdir -p "${UPDATE_TMP}/fasta"
    make_fasta "$i" "$NEWRELEASE" "$NEWSHORTRELEASE" "${NEWTARGET}/uniprot_db" "${UPDATE_TMP}/changed/uniclust${i}_${NEWRELEASE}" "${UPDATE_TMP}/fasta"

    mkdir -p "${UPDATE_TMP}/merge"
    # mimic ab-initio directory structure
    mkdir -p "${UPDATE_TMP}/tmp"
    for t in consensus seed; do
        merge_old_and_new "${UPDATE_TMP}/unchanged" "${OLDTARGET}/tmp/uniclust${i}_${OLDRELEASE}_${t}_db" "${UPDATE_TMP}/changedandnew" "${UPDATE_TMP}/fasta/uniclust${i}_${NEWRELEASE}_${t}_db" "${NEWTARGET}/tmp" "${UPDATE_TMP}/merge"
    done
    make_fasta_archive ${i} "$NEWRELEASE"  "${NEWTARGET}/uniprot_db" "${NEWTARGET}/uniclust${i}_${NEWRELEASE}" "${NEWTARGET}" "${NEWTARGET}/tmp" 
done


UPDATE_TMP="${NEWTARGET}/tmp/update/30"
mkdir -p "${UPDATE_TMP}/clust"
if [ -s "${UPDATE_TMP}/changedandnew" ]; then
    make_hhdatabase "${UPDATE_TMP}/changed" ${NEWRELEASE} "uniclust30" "${NEWTARGET}/uniprot_db" "${NEWTARGET}/tmp/update/clust" 
fi
for t in a3m cs219_binary cs219_plain hhm; do
    merge_old_and_new_legacy "${UPDATE_TMP}/unchanged" "${OLDTARGET}/uniclust30_${OLDRELEASE}_${t}" "${UPDATE_TMP}/changedandnew" "${UPDATE_TMP}/changed/uniclust30_${NEWRELEASE}_${t}" "${NEWTARGET}" "${UPDATE_TMP}/merge"
    ffindex_build -as "${NEWTARGET}/uniclust30_${NEWRELEASE}_${t}.ffdata" "${NEWTARGET}/uniclust30_${NEWRELEASE}_${t}.ffindex"
done

make_hhdatabase_archive "${NEWTARGET}" ${NEWRELEASE} "uniclust30" "${UPDATE_TMP}/changed" 
#fi
for i in 50 90; do 
    UPDATE_TMP="${NEWTARGET}/tmp/update/${i}"
    if [ -s "${UPDATE_TMP}/changedandnew" ]; then
        make_a3m "${UPDATE_TMP}/changed" "${NEWRELEASE}" "uniclust${i}" "${NEWTARGET}/uniprot_db" "${UPDATE_TMP}/clust"
    fi
    merge_old_and_new_legacy "${UPDATE_TMP}/unchanged" "${OLDTARGET}/uniclust${i}_${OLDRELEASE}_a3m" "${UPDATE_TMP}/changedandnew" "${UPDATE_TMP}/changed/uniclust${i}_${NEWRELEASE}_a3m" "${NEWTARGET}" "${UPDATE_TMP}/merge"
done

#fi
UPDATE_TMP="${NEWTARGET}/tmp/update/30"
mkdir -p "${UPDATE_TMP}/annotation"
for type in pfam scop pdb; do
    ln -sf "${UPDATE_TMP}/changed/uniclust30_${NEWRELEASE}_a3m.ffdata" "${UPDATE_TMP}/clust/uniclust30_${NEWRELEASE}_a3m"
    ln -sf "${UPDATE_TMP}/changed/uniclust30_${NEWRELEASE}_a3m.ffindex" "${UPDATE_TMP}/clust/uniclust30_${NEWRELEASE}_a3m.index"
    
    if [ -s "${UPDATE_TMP}/changedids" ]; then
        mmseqs createsubdb "${UPDATE_TMP}/changedids" "${BOOSTTARGET}/tmp/annotation/uniboost10_${BOOSTRELEASE}_${type}_annotation" "${UPDATE_TMP}/annotation/uniboost10_${OLDRELEASE}_${type}_annotation_onlychanged"    
        $RUNNER mmseqs extractdomains "${UPDATE_TMP}/annotation/uniboost10_${OLDRELEASE}_${type}_annotation_onlychanged" "${UPDATE_TMP}/clust/uniclust30_${NEWRELEASE}_a3m" "${UPDATE_TMP}/annotation/uniclust30_${NEWRELEASE}_${type}" --msa-type 1 -e 0.01
    fi
    mkdir -p "${NEWTARGET}/tmp/annotation/"
    merge_old_and_new "${UPDATE_TMP}/unchanged" "${OLDTARGET}/tmp/annotation/uniclust30_${OLDRELEASE}_${type}" "${UPDATE_TMP}/changedids" "${UPDATE_TMP}/annotation/uniclust30_${NEWRELEASE}_${type}" "${NEWTARGET}/tmp/annotation" "${UPDATE_TMP}/merge"
done
make_annotation_archive "${NEWTARGET}" "${NEWRELEASE}" "${NEWTARGET}/tmp/annotation/uniclust30_${NEWRELEASE}"

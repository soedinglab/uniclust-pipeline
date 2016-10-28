#!/bin/bash -ex
#BSUB -q mpi-long+
#BSUB -o out.%J
#BSUB -e err.%J
#BSUB -W 12:00
#BSUB -n 64
#BSUB -a openmpi
#BSUB -m hh
#BSUB -R haswell
#BSUB -R cbscratch
#BSUB -R "span[ptile=16]"

function make_annotation() {
    local BASE="$1"
    local PREFIX="$2"
    local DB="${BASE}/${PREFIX}"
    local LOGPATH="${BASE}/logs"
    mkdir -p "${LOGPATH}"
    local ANNODB="$3"

    mpirun -pernode -- find /dev/shm -type f -exec rm -f {} \;

    local HHPARAMS="-o /dev/null -v 0 -cpu 1 -n 1 -e 0.1"
    mpirun -pernode cp -f ${ANNODB}/pfamA_29.0/pfam_{a3m,hhm,cs219}.ff{data,index} /dev/shm
    sleep 30
    OMP_NUM_THREADS=1 mpirun hhblits_mpi -i "${DB}_a3m" -blasttab "${DB}_pfam" -d "/dev/shm/pfam" ${HHPARAMS}
    mpirun -pernode rm -f /dev/shm/pfam_{a3m,hhm,cs219}.ff{data,index}

    mpirun -pernode cp -f ${ANNODB}/pdb70_18May16/pdb70_{a3m,hhm,cs219}.ff{data,index} /dev/shm
    sleep 30
    OMP_NUM_THREADS=1 mpirun hhblits_mpi -i "${DB}_a3m" -blasttab "${DB}_pdb" -d "/dev/shm/pdb70" ${HHPARAMS}
    mpirun -pernode rm -f /dev/shm/pdb70_{a3m,hhm,cs219}.ff{data,index}

    mpirun -pernode cp -f ${ANNODB}/scop70_1.75/scop70_1.75_{a3m,hhm,cs219}.ff{data,index} /dev/shm
    sleep 30
    OMP_NUM_THREADS=1 mpirun hhblits_mpi -i "${DB}_a3m" -blasttab "${DB}_scop" -d "/dev/shm/scop70_1.75" ${HHPARAMS}
    mpirun -pernode rm -f /dev/shm/scop70_1.75_{a3m,hhm,cs219}.ff{data,index}

    for i in pfam pdb scop; do
        ln -s "${DB}_${i}.ffdata" "${DB}_${i}"
        ln -s "${DB}_${i}.ffindex" "${DB}_${i}.index"
    done
}

function make_lengths() {
    local BASE=$1
    local DB=$2
    local RESULT=$3

    awk '{ print $1"\t"$3-2 }' "$BASE/uniprot_db.index" > "${RESULT}"
    awk '{ sub("\\.a3m", "", $1); print $1"\t"$3-2 }' "${DB}/pfamA_29.0/pfam_cs219.ffindex" >> "${RESULT}"
    awk '{ print $1"\t"$3-2 }' "${DB}/pdb70_18May16/pdb70_cs219.ffindex" >> "${RESULT}"
    awk '{ print $1"\t"$3-2 }' "${DB}/scop70_1.75/scop70_1.75_cs219.ffindex" >> "${RESULT}"
}

function make_tsv() {
    local BASE="$1"
    local RELEASE="$2"
    local PREFIXDOM="${3}_${RELEASE}"
    local PREFIXMSA="${4}_${RELEASE}"
    local DOMDB="${BASE}/${PREFIXDOM}"
    local MSADB="${BASE}/${PREFIXMSA}"
    local LENGTHFILE="$5"
    local TMPDIR="$6"

    export RUNNER="mpirun --pernode --bind-to none"

    ln -sf "${PREFIXMSA}_a3m.ffdata" "${MSADB}_a3m"
    ln -sf "${PREFIXMSA}_a3m.ffindex" "${MSADB}_a3m.index"

    local OUTPUT=""
    for type in pfam scop pdb; do
        $RUNNER mmseqs summarizetabs "${DOMDB}_${type}" "${LENGTHFILE}" "${TMPDIR}/${PREFIXDOM}_${type}_annotation" -e 0.01 --overlap 0.1
        $RUNNER mmseqs extractdomains "${TMPDIR}/${PREFIXDOM}_${type}_annotation" "${MSADB}_a3m" "${TMPDIR}/${PREFIXMSA}_${type}" --msa-type 1 -e 0.01
        tr -d '\000' < "${TMPDIR}/${PREFIXMSA}_${type}" > "${TMPDIR}/${PREFIXMSA}_${type}.tsv"
        OUTPUT="${OUTPUT} ${TMPDIR}/${PREFIXMSA}_${type}.tsv"
    done

    local OUTPATH="${TMPDIR}/${PREFIXMSA}"
    tar -cv --use-compress-program=pigz \
        --show-transformed-names --transform "s|${OUTPATH:1}|uniclust_${RELEASE}/uniclust_${RELEASE}_annotation|g" \
        -f "$TMPDIR/uniclust_${RELEASE}_annotation.tar.gz" \
        ${OUTPUT}
}

source ./paths.sh
a3m_database_extract -i "${TARGET}/uniboost10_${RELEASE}_ca3m" -o "${TARGET}/uniboost10_${RELEASE}_a3m" -d "${TARGET}/uniboost10_${RELEASE}_sequence" -q "${TARGET}/uniboost10_${RELEASE}_header" 
make_annotation "$TARGET" "uniboost10_${RELEASE}" "$HHDBPATH"

TMPDIR="$TARGET/tmp/annotation"
mkdir -p "$TARGET/tmp/annotation"
make_lengths "$TARGET" "$HHDBPATH" "$TMPDIR/lengths"
make_tsv "$TARGET" "${RELEASE}" "uniboost10" "uniclust30" "$TMPDIR/lengths" "$TMPDIR"

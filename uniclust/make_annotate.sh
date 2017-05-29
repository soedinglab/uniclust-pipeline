#!/bin/bash -ex
function notExists() {
    [ ! -f "$1" ]
}

function make_annotation() {
    local BASE="$1"
    local PREFIX="$2"
    local DB="${BASE}/${PREFIX}"
    local LOGPATH="${BASE}/logs"
    mkdir -p "${LOGPATH}"
    local ANNODB="$3"

    local PAUSETIME=10
    local HHPARAMS="-v 0 -cpu 1 -n 1 -e 0.1"

    if notExists "${DB}_pfam.ffdata" || notExists "${DB}_pfam.ffindex"; then
        mpirun -pernode cp -f ${ANNODB}/pfamA_29.0/pfam_{a3m,hhm,cs219}.ff{data,index} /dev/shm
        sleep ${PAUSETIME}
        OMP_NUM_THREADS=1 mpirun hhblits_mpi -i "${DB}_a3m" -blasttab "${DB}_pfam" -d "/dev/shm/pfam" ${HHPARAMS}
        mpirun -pernode rm -f /dev/shm/pfam_{a3m,hhm,cs219}.ff{data,index}
    fi

    if notExists "${DB}_pdb.ffdata" || notExists "${DB}_pdb.ffindex"; then
        mpirun -pernode cp -f ${ANNODB}/pdb70_14Sep16/pdb70_{a3m,hhm,cs219}.ff{data,index} /dev/shm
        sleep ${PAUSETIME}
        OMP_NUM_THREADS=1 mpirun hhblits_mpi -i "${DB}_a3m" -blasttab "${DB}_pdb" -d "/dev/shm/pdb70" ${HHPARAMS}
        mpirun -pernode rm -f /dev/shm/pdb70_{a3m,hhm,cs219}.ff{data,index}
    fi

    if notExists "${DB}_scop.ffdata" || notExists "${DB}_scop.ffindex"; then
        mpirun -pernode cp -f ${ANNODB}/scop70_1.75/scop70_1.75_{a3m,hhm,cs219}.ff{data,index} /dev/shm
        sleep ${PAUSETIME}
        OMP_NUM_THREADS=1 mpirun hhblits_mpi -i "${DB}_a3m" -blasttab "${DB}_scop" -d "/dev/shm/scop70_1.75" ${HHPARAMS}
        mpirun -pernode rm -f /dev/shm/scop70_1.75_{a3m,hhm,cs219}.ff{data,index}
    fi

    for i in pfam pdb scop; do
        ln -sf "${DB}_${i}.ffdata" "${DB}_${i}"
        ln -sf "${DB}_${i}.ffindex" "${DB}_${i}.index"
    done
}

##
# Limitation in .m8 format, it does not have a total sequence length
##
function make_lengths() {
    local BASE=$1
    local DB=$2
    local RESULT=$3

    awk '{ print $1"\t"$3-2 }' "$BASE/uniprot_db.index" > "${RESULT}"
    awk '{ sub("\\.a3m", "", $1); print $1"\t"$3-2 }' "${DB}/pfamA_29.0/pfam_cs219.ffindex" >> "${RESULT}"
    awk '{ print $1"\t"$3-2 }' "${DB}/pdb70_14Sep16/pdb70_cs219.ffindex" >> "${RESULT}"
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
    local TMPPATH="$6"

    export RUNNER="mpirun --pernode --bind-to none"

    ln -sf "${PREFIXMSA}_a3m.ffdata" "${MSADB}_a3m"
    ln -sf "${PREFIXMSA}_a3m.ffindex" "${MSADB}_a3m.index"

    local OUTPUT=""
    for type in pfam scop pdb; do
        $RUNNER mmseqs summarizetabs "${DOMDB}_${type}" "${LENGTHFILE}" "${TMPPATH}/${PREFIXDOM}_${type}_annotation" -e 0.01 --overlap 0.1
        $RUNNER mmseqs extractdomains "${TMPPATH}/${PREFIXDOM}_${type}_annotation" "${MSADB}_a3m" "${TMPPATH}/${PREFIXMSA}_${type}" --msa-type 1 -e 0.01
    done
}

function make_annotation_archive() {
    local BASE="$1"
    local RELEASE="$2"
    local PREFIXMSA="$3"

    local OUTPUT=""
    for type in pfam scop pdb; do
        tr -d '\000' < "${PREFIXMSA}_${type}" > "${PREFIXMSA}_${type}.tsv"
        OUTPUT="${OUTPUT} ${PREFIXMSA}_${type}.tsv"
    done

    tar -cv --use-compress-program=pigz \
        --show-transformed-names --transform "s|${PREFIXMSA:1}|uniclust_${RELEASE}/uniclust_${RELEASE}_annotation|g" \
        -f "${BASE}/uniclust_${RELEASE}_annotation.tar.gz" \
        ${OUTPUT}
}


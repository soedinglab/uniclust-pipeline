#!/bin/bash -ex
#BSUB -q mpi-long+
#BSUB -o out.%J
#BSUB -e err.%J
#BSUB -W 120:00
#BSUB -n 128
#BSUB -a openmpi
#BSUB -m hh
#BSUB -R cbscratch
#BSUB -R "span[ptile=16]"

function make_a3m () {
    local BASE="$1"
    local RELEASE="$2"
    local PREFIXCLUST="$3"
    local CLUSTDB="${BASE}/${PREFIXCLUST}_${RELEASE}"

    local TMPPATH="$4"
    mkdir -p "${TMPPATH}"
    local TMPDB="${TMPPATH}/${PREFIXCLUST}_${RELEASE}"

    mmseqs createseqfiledb "${BASE}/uniprot_db" "${CLUSTDB}" "${TMPDB}_fasta" --min-sequences 2
    ffindex_build -as "${TMPDB}_fasta" "${TMPDB}_fasta.index"
    mv -f "${TMPDB}_fasta" "${TMPDB}_fasta.ffdata"
    mv -f "${TMPDB}_fasta.index" "${TMPDB}_fasta.ffindex"

    make_a3m.sh "${TMPDB}_fasta" "${TMPDB}_a3m" "${TMPPATH}"

    mmseqs createseqfiledb "${BASE}/uniprot_db" "${CLUSTDB}" "${TMPDB}_singleton" --max-sequences 1 --hh-format
    cp -f "${TMPDB}_a3m.ffdata" "${CLUSTDB}_a3m.ffdata"
    cp -f "${TMPDB}_a3m.ffindex" "${CLUSTDB}_a3m.ffindex" 
    ffindex_build -as "${CLUSTDB}_a3m.ffdata" "${CLUSTDB}_a3m.ffindex" -d "${TMPDB}_singleton" -i "${TMPDB}_singleton.index"
}

function make_hhdatabase () {
    local BASE="$1"
    local RELEASE="$2"
    local PREFIXCLUST="$3"
    local CLUSTDB="${BASE}/${PREFIXCLUST}_${RELEASE}"

    local TMPPATH="$4"
    mkdir -p ${TMPPATH}

    make_a3m "${BASE}" "${RELEASE}" "${PREFIXCLUST}" "${TMPPATH}"
    make_hhmake.sh "${CLUSTDB}_a3m" "${CLUSTDB}_hhm" "${TMPPATH}"

    make_cstranslate.sh ${CLUSTDB}_a3m ${CLUSTDB}_cs219
    make_finalize.sh "${BASE}" "$RELEASE" "${PREFIXCLUST}" "${TMPPATH}"
    mv -f "${TMPPATH}/uniclust30_2016_09_hhsuite.tar.gz" "${BASE}"
}

source ./paths.sh
mkdir -p "${TARGET}/tmp/clust"
make_hhdatabase "${TARGET}" "${RELEASE}" "uniclust30" "${TARGET}/tmp/clust"
#make_a3m "${TARGET}" "${RELEASE}" "uniclust50" "${TARGET}/tmp/clust"
#make_a3m "${TARGET}" "${RELEASE}" "uniclust90" "${TARGET}/tmp/clust"

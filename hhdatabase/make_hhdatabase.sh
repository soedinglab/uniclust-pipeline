#!/bin/bash -ex
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/make_finalize.sh

function make_a3m () {
    local BASE="$1"
    local RELEASE="$2"
    local PREFIXCLUST="$3"
    local CLUSTDB="${BASE}/${PREFIXCLUST}_${RELEASE}"

    local SEQUENCEDB="$4"

    local TMPPATH="$5"
    mkdir -p "${TMPPATH}"
    local TMPDB="${TMPPATH}/${PREFIXCLUST}_${RELEASE}"

    mmseqs createseqfiledb "${SEQUENCEDB}" "${CLUSTDB}" "${TMPDB}_fasta" --min-sequences 2
    ffindex_build -as "${TMPDB}_fasta" "${TMPDB}_fasta.index"
    mv -f "${TMPDB}_fasta" "${TMPDB}_fasta.ffdata"
    mv -f "${TMPDB}_fasta.index" "${TMPDB}_fasta.ffindex"

    make_a3m.sh "${TMPDB}_fasta" "${TMPDB}_a3m" "${TMPPATH}"

    mmseqs createseqfiledb "${SEQUENCEDB}" "${CLUSTDB}" "${TMPDB}_singleton" --max-sequences 1 --hh-format
    cp -f "${TMPDB}_a3m.ffdata" "${CLUSTDB}_a3m.ffdata"
    cp -f "${TMPDB}_a3m.ffindex" "${CLUSTDB}_a3m.ffindex" 
    ffindex_build -as "${CLUSTDB}_a3m.ffdata" "${CLUSTDB}_a3m.ffindex" -d "${TMPDB}_singleton" -i "${TMPDB}_singleton.index"
}

function make_hhdatabase () {
    local BASE="$1"
    local RELEASE="$2"
    local PREFIXCLUST="$3"
    local SEQUENCEDB="$4"
    local CLUSTDB="${BASE}/${PREFIXCLUST}_${RELEASE}"

    local TMPPATH="$5"
    mkdir -p ${TMPPATH}

    make_a3m "${BASE}" "${RELEASE}" "${PREFIXCLUST}" "${SEQUENCEDB}" "${TMPPATH}"
    make_hhmake.sh "${CLUSTDB}_a3m" "${CLUSTDB}_hhm" "${TMPPATH}"

    make_cstranslate.sh ${CLUSTDB}_a3m ${CLUSTDB}_cs219

    make_finalize "${BASE}" "$RELEASE" "${PREFIXCLUST}" "${TMPPATH}"
    make_hhdatabase_archive "${BASE}" "$RELEASE" "${PREFIXCLUST}" "${TMPPATH}"
}

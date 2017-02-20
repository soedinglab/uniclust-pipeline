#!/bin/bash -ex
function abspath() {
    if [ -d "$1" ]; then
        (cd "$1"; pwd)
    elif [ -f "$1" ]; then
        if [[ $1 == */* ]]; then
            echo "$(cd "${1%/*}"; pwd)/${1##*/}"
        else
            echo "$(pwd)/$1"
        fi
    fi
}

function make_fasta () {
    i="$1"
    RELEASE="$2"
    SHORTRELEASE="$3"
    
    SEQUENCEDB="$(abspath $4)"
    CLUSTDB="$(abspath $5)"
    TMPPATH="$(abspath $6)"

    # also generated the profiles needed for the uniboost
    $RUNNER mmseqs result2profile "${SEQUENCEDB}" "${SEQUENCEDB}" "${CLUSTDB}" "$TMPPATH/uniclust${i}_${RELEASE}_profile"
    ln -sf "${SEQUENCEDB}_h" "$TMPPATH/uniclust${i}_${RELEASE}_profile_h"
    ln -sf "${SEQUENCEDB}_h.index" "$TMPPATH/uniclust${i}_${RELEASE}_profile_h.index"
    ln -sf "${SEQUENCEDB}_h" "$TMPPATH/uniclust${i}_${RELEASE}_profile_consensus_h"
    ln -sf "${SEQUENCEDB}_h.index" "$TMPPATH/uniclust${i}_${RELEASE}_profile_consensus_h.index"

    mmseqs mergedbs "${CLUSTDB}" "$TMPPATH/uniclust${i}_${RELEASE}_seed_db" "${SEQUENCEDB}_h" "${SEQUENCEDB}" --prefixes ">"

    mmseqs summarizeheaders "${SEQUENCEDB}_h" "${SEQUENCEDB}_h" "${CLUSTDB}" "$TMPPATH/uniclust${i}_${RELEASE}_summary" --summary-prefix "uc${i}-${SHORTRELEASE}"
    mmseqs mergedbs "${CLUSTDB}" "$TMPPATH/uniclust${i}_${RELEASE}_consensus_db" "$TMPPATH/uniclust${i}_${RELEASE}_summary" "$TMPPATH/uniclust${i}_${RELEASE}_profile_consensus" --prefixes ">"
}

function make_fasta_archive () {
    i="$1"
    RELEASE="$2"
    
    SEQUENCEDB="$(abspath $3)"
    CLUSTDB="$(abspath $4)"
    OUTDIR="$(abspath $5)"
    TMPPATH="$(abspath $6)"

 
    sed 's/\x0//g' "$TMPPATH/uniclust${i}_${RELEASE}_seed_db" > "$TMPPATH/uniclust${i}_${RELEASE}_seed.fasta"
    sed 's/\x0//g' "$TMPPATH/uniclust${i}_${RELEASE}_consensus_db" > "$TMPPATH/uniclust${i}_${RELEASE}_consensus.fasta"

    mmseqs createtsv "${SEQUENCEDB}" "${SEQUENCEDB}" "${CLUSTDB}" "$TMPPATH/uniclust${i}_$RELEASE.tsv"

    md5deep "$TMPPATH/uniclust${i}_$RELEASE.tsv" "$TMPPATH/uniclust${i}_${RELEASE}_consensus.fasta" "$TMPPATH/uniclust${i}_${RELEASE}_seed.fasta" \
        > "$TMPPATH/uniclust${i}_${RELEASE}_md5sum"
    sed "s|$TMPPATH/||g" "$TMPPATH/uniclust${i}_${RELEASE}_md5sum" > "$TMPPATH/uniclust${i}_${RELEASE}_md5sum_tmp"
    mv -f "$TMPPATH/uniclust${i}_${RELEASE}_md5sum_tmp" "$TMPPATH/uniclust${i}_${RELEASE}_md5sum"

    tar -cv --use-compress-program=pigz --show-transformed-names \
        --transform "s|${TMPPATH:1}/|uniclust${i}_${RELEASE}/|g" \
        -f "$OUTDIR/uniclust${i}_${RELEASE}.tar.gz" \
        "$TMPPATH/uniclust${i}_$RELEASE.tsv" "$TMPPATH/uniclust${i}_${RELEASE}_consensus.fasta" \
        "$TMPPATH/uniclust${i}_${RELEASE}_seed.fasta" "$TMPPATH/uniclust${i}_${RELEASE}_md5sum"
}

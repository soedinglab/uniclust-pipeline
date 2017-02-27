#!/bin/bash -ex
function make_a3m () {
    local BASE="$1"
    local RELEASE="$2"
    local PREFIXCLUST="$3"
    local CLUSTDB="${BASE}/${PREFIXCLUST}_${RELEASE}"

    local SEQUENCEDB="$4"

    local TMPPATH="$5"
    mkdir -p "${TMPPATH}"
    local TMPDB="${TMPPATH}/${PREFIXCLUST}_${RELEASE}"

    mmseqs createseqfiledb "${SEQUENCEDB}" "${CLUSTDB}" "${TMPDB}_singleton" --max-sequences 1 --hh-format

    mmseqs createseqfiledb "${SEQUENCEDB}" "${CLUSTDB}" "${TMPDB}_fasta" --min-sequences 2
    if [ -s "${TMPDB}_fasta.index" ]; then
        ffindex_build -as "${TMPDB}_fasta" "${TMPDB}_fasta.index"
        mv -f "${TMPDB}_fasta" "${TMPDB}_fasta.ffdata"
        mv -f "${TMPDB}_fasta.index" "${TMPDB}_fasta.ffindex"

        make_a3m.sh "${TMPDB}_fasta" "${TMPDB}_a3m" "${TMPPATH}"
        cp -f "${TMPDB}_a3m.ffdata" "${CLUSTDB}_a3m.ffdata"
        cp -f "${TMPDB}_a3m.ffindex" "${CLUSTDB}_a3m.ffindex" 
    fi

    ffindex_build -as "${CLUSTDB}_a3m.ffdata" "${CLUSTDB}_a3m.ffindex" -d "${TMPDB}_singleton" -i "${TMPDB}_singleton.index"
}

function make_finalize() {
    local BASE="$1"
    local RELEASE="$2"
    local PREFIX="$3"
    local OUTNAME="${PREFIX}_${RELEASE}"
    local DB="${BASE}/${OUTNAME}"
    local TMPPATH="$4"

    cp -f "${DB}_cs219_binary.ffdata" "${DB}_cs219.ffdata"
    cp -f "${DB}_cs219_binary.ffindex" "${DB}_cs219.ffindex"

    ##sort hhms and a3m according to sequence length
    sort -k 3 -n "${DB}_cs219.ffindex" | cut -f1 > "${TMPPATH}_sort_by_length.dat"
    for type in a3m hhm; do
        ffindex_order "${TMPPATH}_sort_by_length.dat" ${DB}_${type}.ff{data,index} ${TMPPATH}_${type}_opt.ff{data,index}

        mv -f "${TMPPATH}_${type}_opt.ffdata" "${DB}_${type}.ffdata"
        mv -f "${TMPPATH}_${type}_opt.ffindex" "${DB}_${type}.ffindex"
    done

    ## Prepare old database format
    #hhblits 2.0.16 does not support sequences with more than 60.000 residues
    #hhblits 2.0.16 has a different cs219 alphabet 'naming' and database format
    awk 'int($3)>=15000' "${DB}_cs219.ffindex" | cut -f1 > "${TMPPATH}_too_long_for_old.dat"
    ffindex_modify -u -f "${TMPPATH}_too_long_for_old.dat" "${DB}_cs219_plain.ffindex"
    reformat_old_cs219_ffindex.py "${DB}_cs219_plain" "${DB}"

    for type in a3m hhm; do
        cp -f "${DB}_${type}.ffindex" "${DB}_${type}_db.index"
        ffindex_modify -u -f "${TMPPATH}_too_long_for_old.dat" "${DB}_${type}_db.index"
        awk '{$1=$1".a3m"}1' "${DB}_${type}_db.index" > "${TMPPATH}_${type}_db.index.tmp"
        mv -f "${TMPPATH}_${type}_db.index.tmp" "${DB}_${type}_db.index"
        sed -i "s/ /\t/g" "${DB}_${type}_db.index"

        #update links
        cd ${BASE}
        ln -sf "${OUTNAME}_${type}.ffdata" "${OUTNAME}_${type}_db"
        cd -
    done

    md5deep ${DB}_{a3m,hhm,cs219}.ff{data,index} "${DB}.cs219" "${DB}.cs219.sizes" ${DB}_{a3m_db,hhm_db}{,.index} > "${DB}_md5sum"
    sed -i "s|${BASE}/||g" "${DB}_md5sum"

    tar -cv --use-compress-program=pigz \
        --show-transformed-names --transform "s|${BASE:1}/|uniclust30_${RELEASE}/|g" \
        -f "${BASE}/uniclust30_${RELEASE}_hhsuite.tar.gz" \
        ${DB}_{a3m,hhm,cs219}.ff{data,index} "${DB}.cs219" "${DB}.cs219.sizes" ${DB}_{a3m_db,hhm_db}{,.index} "${DB}_md5sum"
}

function make_hhdatabase () {
    local BASE="$1"
    local RELEASE="$2"
    local PREFIXCLUST="$3"
    local SEQUENCEDB="$4"
    local CLUSTDB="${BASE}/${PREFIXCLUST}_${RELEASE}"

    local TMPPATH="$5"
    mkdir -p "${TMPPATH}"

    make_a3m "${BASE}" "${RELEASE}" "${PREFIXCLUST}" "${SEQUENCEDB}" "${TMPPATH}"
    make_hhmake.sh "${CLUSTDB}_a3m" "${CLUSTDB}_hhm" "${TMPPATH}"
    make_cstranslate.sh "${CLUSTDB}_a3m" "${CLUSTDB}_cs219"
}

function make_hhdatabase_archive () {
    local BASE="$1"
    local RELEASE="$2"
    local PREFIXCLUST="$3"
    local TMPPATH="$4"
    mkdir -p "${TMPPATH}"

    make_finalize "${BASE}" "$RELEASE" "${PREFIXCLUST}" "${TMPPATH}"
}

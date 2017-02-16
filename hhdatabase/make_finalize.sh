#!/bin/bash -ex

function make_finalize() {
    local BASE="$1"
    local RELEASE="$2"
    local PREFIX="$3"
    local OUTNAME="${PREFIX}_${RELEASE}"
    local DB="${BASE}/${OUTNAME}"
    local TMPDIR="$4"

    cp -f "${DB}_cs219_binary.ffdata" "${DB}_cs219.ffdata"
    cp -f "${DB}_cs219_binary.ffindex" "${DB}_cs219.ffindex"

    ##sort hhms and a3m according to sequence length
    sort -k 3 -n "${DB}_cs219.ffindex" | cut -f1 > "${TMPDIR}_sort_by_length.dat"
    for type in a3m hhm; do
        ffindex_order "${TMPDIR}_sort_by_length.dat" ${DB}_${type}.ff{data,index} ${TMPDIR}_${type}_opt.ff{data,index}

        mv -f "${TMPDIR}_${type}_opt.ffdata" "${DB}_${type}.ffdata"
        mv -f "${TMPDIR}_${type}_opt.ffindex" "${DB}_${type}.ffindex"
    done

    ## Prepare old database format
    #hhblits 2.0.16 does not support sequences with more than 60.000 residues
    #hhblits 2.0.16 has a different cs219 alphabet 'naming' and database format
    awk 'int($3)>=15000' "${DB}_cs219.ffindex" | cut -f1 > "${TMPDIR}_too_long_for_old.dat"
    ffindex_modify -u -f "${TMPDIR}_too_long_for_old.dat" "${DB}_cs219_plain.ffindex"
    reformat_old_cs219_ffindex.py "${DB}_cs219_plain" "${DB}"

    for type in a3m hhm; do
        cp -f "${DB}_${type}.ffindex" "${DB}_${type}_db.index"
        ffindex_modify -u -f "${TMPDIR}_too_long_for_old.dat" "${DB}_${type}_db.index"
        awk '{$1=$1".a3m"}1' "${DB}_${type}_db.index" > "${TMPDIR}_${type}_db.index.tmp"
        mv -f "${TMPDIR}_${type}_db.index.tmp" "${DB}_${type}_db.index"
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
        -f "$TMPDIR/uniclust30_${RELEASE}_hhsuite.tar.gz" \
        ${DB}_{a3m,hhm,cs219}.ff{data,index} "${DB}.cs219" "${DB}.cs219.sizes" ${DB}_{a3m_db,hhm_db}{,.index} "${DB}_md5sum"
}

make_finalize $1 $2 $3 $4

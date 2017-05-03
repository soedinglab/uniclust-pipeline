#!/bin/bash -ex
#BSUB -q mpi-long+
#BSUB -o log-website-db.%J
#BSUB -e log-website-db.%J
#BSUB -W 120:00
#BSUB -n 16
#BSUB -a openmpi
#BSUB -m hh
#BSUB -R haswell
#BSUB -R cbscratch
#BSUB -R "span[ptile=16]"

function make_release_db() {
    local BASE="$1"
	local RELEASE="$2"
    local TMPDIR="$3"
    local LOOKUP="$4"
    local WEBROOT="${5}/${RELEASE}"

    if [ -d "${WEBROOT}/postgres" ]; then
        return 0
    fi

    initdb --no-locale -D "${WEBROOT}/postgres" 

    pg_ctl -w -D "${WEBROOT}/postgres" -l "${TMPDIR}/pglog" start

    createdb --locale=C -w

    psql -v release="${RELEASE}" -v file="$LOOKUP" < "uniclust-web/lookup.schema"

    mkdir -p ${TMPDIR}
	for i in 30 50 90; do
        if [[ ! -f "${TMPDIR}/uniclust${i}_${RELEASE}.importentries" ]]; then
            mmseqs result2stats "${BASE}/uniprot_db" "${BASE}/uniprot_db" "${BASE}/uniclust${i}_${RELEASE}" "${TMPDIR}/uniclust${i}_${RELEASE}_count" --stat linecount
            mmseqs prefixid "${TMPDIR}/uniclust${i}_${RELEASE}_count" "${TMPDIR}/uniclust${i}_${RELEASE}_entries"
            tr -d '\000' < "${TMPDIR}/uniclust${i}_${RELEASE}_entries" > "${TMPDIR}/uniclust${i}_${RELEASE}_entriesnn"
            mv -f "${TMPDIR}/uniclust${i}_${RELEASE}_entriesnn" "${TMPDIR}/uniclust${i}_${RELEASE}_entries"
            awk -v type="${i}" '{  print $1"\t"type"\t"$2 }' "${TMPDIR}/uniclust${i}_${RELEASE}_entries" > "${TMPDIR}/uniclust${i}_${RELEASE}.importentries"
            rm -f "${TMPDIR}/uniclust${i}_${RELEASE}_entries.index" "${TMPDIR}/uniclust${i}_${RELEASE}_count" "${TMPDIR}/uniclust${i}_${RELEASE}_count.index" "${TMPDIR}/uniclust${i}_${RELEASE}_entries"
        fi
        psql -v release="${RELEASE}" -v file="${TMPDIR}/uniclust${i}_${RELEASE}.importentries" < "uniclust-web/entries.schema"
	done
    psql -v release="${RELEASE}" < "uniclust-web/entries-index.schema"

    for i in 30 50 90; do
        if [[ ! -f "${TMPDIR}/uniclust${i}_${RELEASE}.importclustering_sorted" ]]; then
            mmseqs prefixid "${BASE}/uniclust${i}_${RELEASE}" "${TMPDIR}/uniclust${i}_${RELEASE}_cluster_id_mapping.tsv"
            rm -f "${TMPDIR}/uniclust${i}_${RELEASE}_cluster_id_mapping.tsv.index"
            tr -d '\000' < "${TMPDIR}/uniclust${i}_${RELEASE}_cluster_id_mapping.tsv" > "${TMPDIR}/uniclust${i}_${RELEASE}_cluster_id_mapping.tsv_nonull"
            mv -f "${TMPDIR}/uniclust${i}_${RELEASE}_cluster_id_mapping.tsv_nonull" "${TMPDIR}/uniclust${i}_${RELEASE}_cluster_id_mapping.tsv"
            awk -v type="${i}" '{ print $1"\t"type"\t"$2 }' "${TMPDIR}/uniclust${i}_${RELEASE}_cluster_id_mapping.tsv" > "${TMPDIR}/uniclust${i}_${RELEASE}.importclustering"
            LC_ALL=C sort -u -S60G --parallel=16 --temporary-directory=/dev/shm "${TMPDIR}/uniclust${i}_${RELEASE}.importclustering" > "${TMPDIR}/uniclust${i}_${RELEASE}.importclustering_sorted"
        fi
        psql -v release="${RELEASE}" -v file="${TMPDIR}/uniclust${i}_${RELEASE}.importclustering_sorted" < "uniclust-web/clustering.schema"
    done

    psql -v release="${RELEASE}" < "uniclust-web/clustering-index.schema"
    psql -v release="${RELEASE}" < "uniclust-web/permissions.schema"

    pg_ctl -D "${WEBROOT}/postgres" -l "${TMPDIR}/pglog" stop
}

source paths-latest.sh

hasCommand initdb
hasCommand psql
hasCommand pg_ctl

MMTMP="${TARGET}/tmp/kb"
mkdir -p "${MMTMP}"

awk '{ gsub(/_[[:digit:]]*/, "", $2); print $1"\t"$2; }' "${TARGET}/uniprot_db.lookup" > "${MMTMP}/uniprot_db.lookup_nosplit"
make_release_db "${TARGET}" "${RELEASE}" "${MMTMP}" "${MMTMP}/uniprot_db.lookup_nosplit" "${UNICLUSTWEB}" 


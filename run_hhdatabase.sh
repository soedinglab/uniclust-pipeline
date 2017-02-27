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

source hhdatabase/make_hhdatabase.sh

source ./paths.sh
mkdir -p "${TARGET}/tmp/clust"
make_hhdatabase "${TARGET}" "${RELEASE}" "uniclust30" "${TARGET}/uniprot_db" "${TARGET}/tmp/clust"
make_hhdatabase_archive "${TARGET}" "${RELEASE}" "uniclust30" "${TARGET}/tmp/clust"
make_a3m "${TARGET}" "${RELEASE}" "uniclust50" "${TARGET}/uniprot_db" "${TARGET}/tmp/clust"
make_a3m "${TARGET}" "${RELEASE}" "uniclust90" "${TARGET}/uniprot_db" "${TARGET}/tmp/clust"

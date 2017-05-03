#!/bin/bash -ex
#BSUB -q mpi-long+
#BSUB -o log-hhdatabase.%J
#BSUB -e log-hhdatabase.%J
#BSUB -W 120:00
#BSUB -n 128
#BSUB -a openmpi
#BSUB -m hh
#BSUB -R cbscratch
#BSUB -R "span[ptile=16]"

source paths-latest.sh

source hhdatabase/make_hhdatabase.sh

mkdir -p "${TARGET}/tmp/clust"
make_hhdatabase "${TARGET}" "${RELEASE}" "uniclust30" "${TARGET}/uniprot_db" "${TARGET}/tmp/clust"
make_hhdatabase_archive "${TARGET}" "${RELEASE}" "uniclust30" "${TARGET}/tmp/clust"
make_a3m "${TARGET}" "${RELEASE}" "uniclust50" "${TARGET}/uniprot_db" "${TARGET}/tmp/clust"
make_a3m "${TARGET}" "${RELEASE}" "uniclust90" "${TARGET}/uniprot_db" "${TARGET}/tmp/clust"

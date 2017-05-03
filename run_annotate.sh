#!/bin/bash -ex
#BSUB -q mpi-long+
#BSUB -o log-annotate.%J
#BSUB -e log-annotate.%J
#BSUB -W 120:00
#BSUB -n 240
#BSUB -a openmpi
#BSUB -m hh
#BSUB -R cbscratch
#BSUB -R "span[ptile=16]"

source paths-latest.sh

source uniclust/make_annotate.sh

a3m_database_extract -i "${TARGET}/uniboost10_${RELEASE}_ca3m" -o "${TARGET}/uniboost10_${RELEASE}_a3m" -d "${TARGET}/uniboost10_${RELEASE}_sequence" -q "${TARGET}/uniboost10_${RELEASE}_header" 
make_annotation "$TARGET" "uniboost10_${RELEASE}" "$HHDBPATH"

TMPPATH="$TARGET/tmp/annotation"
mkdir -p "$TARGET/tmp/annotation"
make_lengths "$TARGET" "$HHDBPATH" "$TMPPATH/lengths"
make_tsv "$TARGET" "${RELEASE}" "uniboost10" "uniclust30" "$TMPPATH/lengths" "$TMPPATH"
make_annotation_archive "$TARGET" "${RELEASE}" "${TMPPATH}/uniclust30_${RELEASE}"

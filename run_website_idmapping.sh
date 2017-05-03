#!/bin/bash -ex
#BSUB -q mpi-long+
#BSUB -o log-website-data.%J
#BSUB -e log-website-data.%J
#BSUB -W 120:00
#BSUB -n 16
#BSUB -a openmpi
#BSUB -m hh
#BSUB -R haswell
#BSUB -R cbscratch
#BSUB -R "span[ptile=16]"

source paths-latest.sh
MMTMP="${TARGET}/tmp/kb"
mkdir -p "${MMTMP}"
#if [[ -f "${MMTMP}/uniprotkb_kw_idmapping_import" ]]; then
# echo "import file already exists" && exit 1
#fi

mmseqs convertkb "${UNIPROTBASE}/uniprot_sprot_trembl.dat" "${MMTMP}/uniprotkb_${RELEASE}" --kb-columns "14"
mmseqs prefixid "${MMTMP}/uniprotkb_${RELEASE}_KW" "${MMTMP}/uniprotkb_${RELEASE}_KW_lines_prefix"
tr -d '\000' < "${MMTMP}/uniprotkb_${RELEASE}_KW_lines_prefix" > "${MMTMP}/uniprotkb_${RELEASE}_KW_lines_prefixnn"
mv -f "${MMTMP}/uniprotkb_${RELEASE}_KW_lines_prefixnn" "${MMTMP}/uniprotkb_${RELEASE}_KW_lines_prefix"
rm -f "${MMTMP}/uniprotkb_${RELEASE}_KW_lines_prefix.index" "${MMTMP}/uniprotkb_${RELEASE}_KW" "${MMTMP}/uniprotkb_${RELEASE}_KW.index"

gawk 'BEGIN {FS = "\t"} { gsub(/{.*$/, "", $3); gsub(/(^[[:space:]]+|[[:space:]]+$)/, "", $3); gsub(/.+}/, "", $3); if($3 && length($3) > 3 && $3 != "Complete proteome" && $3 != "Reference proteome") print $1"\t"$3}' \
    "${MMTMP}/uniprotkb_${RELEASE}_KW_lines_prefix" \
    | mawk 'BEGIN {FS="\t"} {print $1"\tUniProt Keyword\t"$2}' \
        > "${MMTMP}/uniprotkb_kw_idmapping_import"

mawk 'length($3) > 3 { print $0 }' "${UNIPROTBASE}/idmapping.dat" >> "${MMTMP}/uniprotkb_kw_idmapping_import"

#uniclust-web/import_id_types.sh "${MMTMP}/uniprotkb_kw_idmapping_import"


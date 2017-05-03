#!/bin/bash -ex
VERSION=($(curl -s ftp://ftp.expasy.org/databases/uniprot/current_release/RELEASE.metalink | gawk 'match($0, /<version>([0-9]{2})([0-9]{2})_([0-9]{2})<\/version>/, r) { print r[1]"\t"r[2]"\t"r[3] }')) 

YEAR1="${VERSION[0]}"
YEAR2="${VERSION[1]}"
MONTH="${VERSION[2]}"

if [[ -z "${YEAR1}" ]] || [[ -z "${YEAR2}" ]] || [[ -z "${MONTH}" ]]; then
    echo "Could not get version information from Uniprot"
    exit 1
fi

if [[ -f paths-latest.sh ]]; then
    source paths-latest.sh
fi

export RELEASE="${YEAR1}${YEAR2}_${MONTH}"
export SHORTRELEASE="${YEAR2}${MONTH}"
export BOOSTRELEASE

function isNotReleaseMonth() {
    return $(($1 % 2 == 0))
}

if isNotReleaseMonth "$MONTH"; then
    echo "No release this month"
    exit 0
fi


#if [[ -d "uniprot/${RELEASE}" ]]; then
#    exit 0
#fi

function downloadEverything() {
mkdir -p "uniprot/${RELEASE}"
    local RELEASE="$1"
    wget "ftp://ftp.expasy.org/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.fasta.gz" -O "uniprot/${RELEASE}/uniprot_sprot.fasta.gz"
    wget "ftp://ftp.expasy.org/databases/uniprot/current_release/knowledgebase/complete/uniprot_trembl.fasta.gz" -O "uniprot/${RELEASE}/uniprot_trembl.fasta.gz" 
    cat "uniprot/${RELEASE}/uniprot_sprot.fasta.gz" "uniprot/${RELEASE}/uniprot_trembl.fasta.gz" > "uniprot/${RELEASE}/uniprot_sprot_trembl.fasta.gz"
    rm -f "uniprot/${RELEASE}/uniprot_sprot.fasta.gz" "uniprot/${RELEASE}/uniprot_trembl.fasta.gz"

    wget "ftp://ftp.expasy.org/databases/uniprot/current_release/knowledgebase/complete/uniprot_sprot.dat.gz" -O "uniprot/${RELEASE}/uniprot_sprot.dat.gz"
    wget "ftp://ftp.expasy.org/databases/uniprot/current_release/knowledgebase/complete/uniprot_trembl.dat.gz" -O "uniprot/${RELEASE}/uniprot_trembl.dat.gz" 
    cat "uniprot/${RELEASE}/uniprot_sprot.dat.gz" "uniprot/${RELEASE}/uniprot_trembl.dat.gz" > "uniprot/${RELEASE}/uniprot_sprot_trembl.dat.gz"
    rm -f "uniprot/${RELEASE}/uniprot_sprot.dat.gz" "uniprot/${RELEASE}/uniprot_trembl.dat.gz"

    wget "ftp://ftp.expasy.org/databases/uniprot/current_release/knowledgebase/idmapping/idmapping.dat.gz" -O "uniprot/${RELEASE}/idmapping.dat.gz"

    wget "ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz" -O "uniprot/${RELEASE}/taxdump.tar.gz"
}

#downloadEverything ${RELEASE}
./mo paths.template > paths-${RELEASE}.sh
mv -f paths-latest.sh paths-old.sh
ln -sf paths-${RELEASE}.sh paths-latest.sh
exit 0

if $(($MONTH == 12)); then
    bsub -J "main-$RELEASE" < run_main.sh 
    bsub -J "hhdb-$RELEASE" -w "done(main-${RELASE})" < run_hhdatabase.sh
    bsub -J "done-$RELEASE" -w "done(hhdb-${RELEASE})" < run_annotate.sh
else
    bsub -J "done-$RELEASE" < update_workflow.sh
fi

bsub -J "down-$RELEASE" -w "done(done-${RELEASE})" < run_upload.sh 
bsub -J "web1-$RELEASE" -w "done(done-${RELEASE})" < run_website.sh 
bsub -J "psql-$RELEASE" -w "done(done-${RELEASE})" < run_website_db.sh 
bsub -J "srch-$RELEASE" -w "done(psql-${RELEASE})" < run_website_idmapping.sh

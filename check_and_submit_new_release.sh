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
    local RELEASE="$1"

    mkdir -p "uniprot/${RELEASE}"
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
#mv -f paths-latest.sh paths-old.sh
ln -sf paths-${RELEASE}.sh paths-latest.sh

source paths-latest.sh

LSF=0
function submit() {
    if [[ $LSF == 0 ]]; then
        $1
    else
        bsub ${@:2} < $1
    fi
}

if true || [[ $MONTH == 12 ]]; then
    submit run_main.sh -J "main-$RELEASE"
    submit run_hhdatabase.sh -J "hhdb-$RELEASE" -w "done(main-${RELASE})"
    submit run_annotate.sh -J "done-$RELEASE" -w "done(hhdb-${RELEASE})"
else
    submit update_workflow.sh -J "done-$RELEASE"
fi

#submit run_upload.sh -J "down-$RELEASE" -w "done(done-${RELEASE})"
submit run_website.sh -J "web1-$RELEASE" -w "done(done-${RELEASE})"
submit run_website_db.sh -J "psql-$RELEASE" -w "done(done-${RELEASE})"
submit run_website_idmapping.sh -J "srch-$RELEASE" -w "done(psql-${RELEASE})"

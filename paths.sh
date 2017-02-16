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

SCRIPTPATH="$( cd $(dirname $0) ; pwd )"

HHDBPATH="/cbscratch/mmirdit/databases"

MMDIR="/cbscratch/mmirdit/uniclust/pipeline/mmseqs"
PATH="$MMDIR/bin:$MMDIR/util:$PATH"

HHLIB="/cbscratch/mmirdit/uniclust/pipeline/hh-suite"
PATH="$HHLIB/bin:$HHLIB/scripts:$PATH"

HHDB="${SCRIPTPATH}/hhdatabase"
PATH="$HHDB:$PATH"

UCDIR="${SCRIPTPATH}"

PATH="$UCDIR:$UCDIR/annotation:$PATH"

export FASTA="./input.fasta"
export RELEASE="2016_09"
export SHORTRELEASE="1609"
export BASE="output"
export TARGET="$(abspath ./output/${RELEASE})"

export PATH
export MMDIR
export HHLIB
export HHDB
export HHDBPATH

export OMPI_MCA_btl_openib_ib_timeout=31

function hasCommand() {
	command -v $1 >/dev/null 2>&1 || { echo "Please make sure that $1 is in \$PATH."; exit 1; }
}

hasCommand mmseqs
hasCommand awk
hasCommand tar
hasCommand pigz
hasCommand cstranslate_mpi
if [[ ! -e ${HHLIB}/data/cs219.lib ]] || [[ ! -e ${HHLIB}/data/context_data.lib ]]; then
    echo "Missing required cstranslate data, check HHLIB env var!"
    exit 1;
fi
hasCommand sed
hasCommand md5deep
hasCommand clustalo
hasCommand kalign
hasCommand timeout
hasCommand python
hasCommand python3
hasCommand hhblits_mpi

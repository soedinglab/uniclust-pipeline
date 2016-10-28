#!/bin/bash -ex

HHDBPATH="/cbscratch/mmirdit/databases"

MMDIR="/cbscratch/mmirdit/uniclust/pipeline/mmseqs"
PATH="$MMDIR/bin:$MMDIR/util:$PATH"

HHLIB="/cbscratch/mmirdit/uniclust/pipeline/hh-suite"
PATH="$HHLIB/bin:$HHLIB/scripts:$PATH"

HHDB="/cbscratch/mmirdit/uniclust/pipeline/hhdatabase"
PATH="$HHDB:$PATH"

UCDIR="/cbscratch/mmirdit/uniclust/pipeline"

PATH="$UCDIR:$UCDIR/annotation:$PATH"

export FASTA="./input.fasta"
export RELEASE="2016_06"
export SHORTRELEASE="1606"
export BASE="output"
export TARGET="./output/${RELEASE}"

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
hasCommand sed
hasCommand md5deep
hasCommand clustalo
hasCommand kalign
hasCommand timeout
hasCommand python
hasCommand python3
hasCommand hhblits_mpi

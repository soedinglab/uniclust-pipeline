#!/bin/bash -ex

function make_cstranslate() {
	readonly INPUT=$1
	readonly OUTPUT=$2
	OMP_NUM_THREADS=1 mpirun cstranslate_mpi -A ${HHLIB}/data/cs219.lib -D ${HHLIB}/data/context_data.lib -x 0.3 -c 4 -I a3m --both -i $INPUT -o $OUTPUT
}

make_cstranslate $1 $2

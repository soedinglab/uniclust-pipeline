#!/bin/bash

function make_hhmake() { 
	readonly INPUT=$1
	readonly OUTPUT=$2
	readonly TMPDIR=$3

	readonly PREFIX=${INPUT##*/}
	readonly TMPOUT="${TMPDIR}/${PREFIX}"

	
	echo "get huge a3m"
	mpirun ffindex_apply_mpi ${INPUT}.ff{data,index} -i ${TMPOUT}_hhm_sizes.ffindex -d ${TMPOUT}_hhm_sizes.ffdata -- grep -c "^>"

	echo "cat processing"
	get_small_a3m_entries.py ${TMPOUT}_hhm_sizes ${TMPOUT}_small_a3ms.dat
	cp ${INPUT}.ffindex ${TMPOUT}_hhm_big_a3m.ffindex
	ffindex_modify -u -f ${TMPOUT}_small_a3ms.dat ${TMPOUT}_hhm_big_a3m.ffindex

	echo "calculate hhm"
	OMP_NUM_THREADS=1 mpirun ffindex_apply_mpi -d ${OUTPUT}.ffdata -i ${OUTPUT}.ffindex ${INPUT}.ffdata ${TMPOUT}_hhm_big_a3m.ffindex -- hhmake -i stdin -o stdout -v 0

	echo "optimization"
	ffindex_build -as ${OUTPUT}.ff{data,index}
}

make_hhmake $1 $2 $3

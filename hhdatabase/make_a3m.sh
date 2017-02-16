#!/bin/bash -ex

function make_a3m() {
	readonly INPUT=$1
	readonly OUTPUT=$2
	readonly TMPPATH=$3
	
	readonly PREFIX=${INPUT##*/}
	readonly TMPOUT="${TMPPATH}/${PREFIX}"

	#build a3m's
    export OMP_NUM_THREADS=1
	mpirun -npernode 16 --bind-to none ffindex_apply_mpi -d ${OUTPUT}.ffdata -i ${OUTPUT}.ffindex ${INPUT}.ff{data,index} -- fasta_to_msa_a3m.sh 1h 6000 1

	#remove presumably wrong clusters
	grep "\s1$" ${OUTPUT}.ffindex | cut -f1 > ${TMPOUT}_misaligned_a3ms_0.dat

	nr_entries=$(wc -l ${TMPOUT}_misaligned_a3ms_0.dat | cut -f1 -d" ")
	if [ "$nr_entries" == "0" ]; then 
		exit 0;
	fi

	ffindex_modify -u -f ${TMPOUT}_misaligned_a3ms_0.dat ${OUTPUT}.ffindex

	##retry presumably wrong clusters with more memory, more threads and longer runtime
	##first repair iteration
	while read f;
	do
        ffindex_get ${INPUT}.ff{data,index} $f > $f
        ffindex_build -as ${TMPOUT}_missing_fasta_1.ff{data,index} $f
        rm -f $f
    done < ${TMPOUT}_misaligned_a3ms_0.dat

	#retry presumably wrong clusters with more memory, more threads and longer runtime
    export OMP_NUM_THREADS=8
	mpirun -npernode 2 --bind-to none ffindex_apply_mpi -d ${TMPOUT}_missing_a3m_1.ffdata -i ${TMPOUT}_missing_a3m_1.ffindex ${TMPOUT}_missing_fasta_1.ff{data,index} -- fasta_to_msa_a3m.sh 3h 60000 8
	grep "\s1$" ${TMPOUT}_missing_a3m_1.ffindex | cut -f1 > ${TMPOUT}_misaligned_a3ms_1.dat
	ffindex_modify -u -f ${TMPOUT}_misaligned_a3ms_1.dat ${TMPOUT}_missing_a3m_1.ffindex
	ffindex_build -as ${OUTPUT}.ff{data,index} -i ${TMPOUT}_missing_a3m_1.ffindex -d ${TMPOUT}_missing_a3m_1.ffdata

	##second repair iteration
	while read f;
	do
        ffindex_get ${INPUT}.ff{data,index} $f > $f
        ffindex_build -as ${TMPOUT}_missing_fasta_2.ff{data,index} $f
        rm -f $f
	done < ${TMPOUT}_misaligned_a3ms_1.dat

	#retry presumably wrong clusters with more memory, more threads and longer runtime
	nr_entries=$(wc -l ${TMPOUT}_misaligned_a3ms_1.dat | cut -f1 -d" ")
    if [ "$nr_entries" == "0" ]; then
        exit 0;
    fi

    export OMP_NUM_THREADS=16
	mpirun -npernode 1 --bind-to none ffindex_apply_mpi -d ${TMPOUT}_missing_a3m_2.ffdata -i ${TMPOUT}_missing_a3m_2.ffindex ${TMPOUT}_missing_fasta_2.ff{data,index} -- fasta_to_msa_a3m.sh 8h 120000 16
	grep "\s1$" ${TMPOUT}_missing_a3m_2.ffindex | cut -f1 > ${TMPOUT}_misaligned_a3ms_2.dat
	ffindex_modify -u -f ${TMPOUT}_misaligned_a3ms_2.dat ${TMPOUT}_missing_a3m_2.ffindex

	##merging
	ffindex_build -as ${OUTPUT}.ff{data,index} -i ${TMPOUT}_missing_a3m_2.ffindex -d ${TMPOUT}_missing_a3m_2.ffdata
}

make_a3m $1 $2 $3

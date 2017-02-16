#!/bin/bash -ex
#BSUB -q mpi-long+
#BSUB -o out.%J
#BSUB -e err.%J
#BSUB -W 330:00
#BSUB -n 160
#BSUB -a openmpi
#BSUB -m hh
#BSUB -R cbscratch
#BSUB -R "span[ptile=16]"
export RUNNER="mpirun --pernode --bind-to none"
export COMMON="--threads 16"
export OMP_NUM_THREADS=16
source ./paths.sh
./uniclust_workflow_martin.sh "${FASTA}" "${BASE}" "${RELEASE}" "${SHORTRELEASE}"

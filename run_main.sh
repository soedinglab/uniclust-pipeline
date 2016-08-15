#!/bin/bash -ex
#BSUB -q mpi-long+
#BSUB -o out.%J
#BSUB -e err.%J
#BSUB -W 120:00
#BSUB -n 80
#BSUB -a openmpi
#BSUB -m hh
#BSUB -R haswell
#BSUB -R cbscratch
#BSUB -R "span[ptile=16]"
export RUNNER="mpirun --pernode --bind-to none"
export COMMON="--threads 16"
export OMP_NUM_THREADS=16
source ./paths.sh
./uniclust_workflow.sh "${FASTA}" "${BASE}" "${RELEASE}" "${SHORTRELEASE}"

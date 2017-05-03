#!/bin/bash -ex
#BSUB -q mpi-long+
#BSUB -o log-workflow.%J
#BSUB -e log-workflow.%J
#BSUB -W 330:00
#BSUB -n 160
#BSUB -a openmpi
#BSUB -m hh
#BSUB -R cbscratch
#BSUB -R "span[ptile=16]"
export RUNNER="mpirun --pernode --bind-to none"
export COMMON="--threads 16"
export OMP_NUM_THREADS=16
source paths-latest.sh

uniclust_workflow.sh "${FASTA}" "${BASE}" "${RELEASE}" "${SHORTRELEASE}"

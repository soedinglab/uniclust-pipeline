# Uniclust Pipeline

## Setup
Make sure to install the HH-Suite3 and MMseqs2 and adjust the paths in `paths.sh`.
Also make sure that `awk, tar, pigz, cstranslate_mpi, sed, md5deep, clustalo, kalign, timeout` are all installed and available in PATH.

## Usage
To build your own databases based on the uniclust pipeline you can use the following three scripts:

* `run_main.sh`: Run Main does the clustering, builds the `uniclust30/50/90` and does the sequence enrichment of the `uniboost10/20/30` databases.
* `run_hhdatabase.sh`: Builds the `uniclust30_hhsuite` database
* `run_annotate.sh`: Builds the annotation files

Make sure to run the scripts in this order.

## LSF
The pipeline was custom build for out LSF cluster computing environment and can be submitted to the LSF with `bsub < run_mpi.sh` for example.
Please adjust the LSF parameters at the beginning of the `run_` scripts. The pipeline assumes a shared file system between the computing nodes.

## Webserver & Downloads
We provide a webserver and the Uniclust based on the UniProtKB on <https://uniclust.mmseqs.com/>.

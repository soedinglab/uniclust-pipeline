#!/bin/bash -ex
[ "$#" -lt 2  ] && echo "Please provide <sequenceDB> <outDir>"  && exit 1;
[ ! -f "$1"   ] && echo "Sequence database $1 not found!"       && exit 1;
[   -d "$2"   ] && echo "Output directory $2 exists already!"   && exit 1;

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

RELEASE="${3:-$(date "+%Y_%m")}"
SHORTRELEASE="${4:-$(date "+%y%m")}"

INPUT=$1
OUTDIR=$2/$RELEASE

TMPPATH=$OUTDIR/tmp
mkdir -p $TMPPATH

OUTDIR=$(abspath $OUTDIR)
TMPPATH=$(abspath $TMPPATH)

PREFILTER_COMMON="$COMMON"
PREFILTER_FRAG_PAR="--max-seqs 4000 --min-ungapped-score 100 --comp-bias-corr 0  -s 1 ${PREFILTER_COMMON}"
PREFILTER1_PAR="--max-seqs 100  -c 0.9 --comp-bias-corr 1 -s 2 ${PREFILTER_COMMON}"
PREFILTER2_PAR="--max-seqs 300  -c 0.8 --comp-bias-corr 1 -s 6  ${PREFILTER_COMMON}"
ALIGNMENT_COMMON="$COMMON -e 0.001 --max-seq-len 32768 --max-rejected 2147483647"
ALIGNMENT0_PAR="--max-seqs 100  -c 0.9 --alignment-mode 2 --min-seq-id 0.9 --comp-bias-corr 0 ${ALIGNMENT_COMMON}"
ALIGNMENT1_PAR="--max-seqs 100 -c 0.8 --alignment-mode 2 --min-seq-id 0.9 --comp-bias-corr 1 ${ALIGNMENT_COMMON}"
ALIGNMENT2_PAR="--max-seqs 300 -c 0.8 --alignment-mode 3 --min-seq-id 0.3 --comp-bias-corr 1 ${ALIGNMENT_COMMON}"
CLUSTER_FRAG_PAR="--cluster-mode 2"
CLUSTER0_PAR="--cluster-mode 2"
CLUSTER1_PAR="--cluster-mode 0"
CLUSTER2_PAR="--cluster-mode 0"
SEARCH_PAR="$COMMON --profile --k-score 100"
CSTRANSLATE_PAR="-x 0.3 -c 4 -A $HHLIB/data/cs219.lib -D $HHLIB/data/context_data.lib -I ca3m -f -b"

SEQUENCE_DB="$OUTDIR/uniprot_db"

export OMP_PROC_BIND=true
# we split all sequences that are above 14k in N/14k parts
mmseqs createdb "$INPUT" "${SEQUENCE_DB}" --max-seq-len 14000

STEP="_FRAG"
INPUT="${SEQUENCE_DB}"
$RUNNER mmseqs prefilter "$INPUT" "$INPUT" "$TMPPATH/pref_step$STEP" ${PREFILTER_FRAG_PAR}
date --rfc-3339=seconds
mmseqs rescorediagonal  "$INPUT" "$INPUT" "$TMPPATH/pref_step$STEP" "$TMPPATH/aln_step$STEP" --min-seq-id 0.9 --target-cov 0.95
date --rfc-3339=seconds
mmseqs clust $INPUT "$TMPPATH/aln_step$STEP" "$TMPPATH/clu_frag" ${CLUSTER_FRAG_PAR}
date --rfc-3339=seconds
awk '{ print $1 }' "$TMPPATH/clu_frag.index" > "$TMPPATH/order_frag"
date --rfc-3339=seconds
mmseqs createsubdb "$TMPPATH/order_frag" $INPUT "$TMPPATH/input_step_redundancy"
date --rfc-3339=seconds

# filter redundancy 
INPUT="$TMPPATH/input_step_redundancy"
date --rfc-3339=seconds
mmseqs clusthash $INPUT "$TMPPATH/aln_redundancy" --min-seq-id 0.9
date --rfc-3339=seconds
mmseqs clust $INPUT "$TMPPATH/aln_redundancy" "$TMPPATH/clu_redundancy" ${CLUSTER_FRAG_PAR}
date --rfc-3339=seconds
awk '{ print $1 }' "$TMPPATH/clu_redundancy.index" > "$TMPPATH/order_redundancy"
mmseqs createsubdb "$TMPPATH/order_redundancy" $INPUT "$TMPPATH/input_step0"


date --rfc-3339=seconds
# go down to 90%
STEP=0
INPUT="$TMPPATH/input_step0"
# Remove the fragments from the prefilter, in order not to recompute prefilter
mmseqs createsubdb  "$TMPPATH/order_redundancy"  "$TMPPATH/pref_step_FRAG"  "$TMPPATH/pref_step_FRAG_filtered"
mmseqs filterdb "$TMPPATH/pref_step_FRAG_filtered" "$TMPPATH/pref_step$STEP" --filter-file "$TMPPATH/order_redundancy"
date --rfc-3339=seconds
$RUNNER mmseqs align "$INPUT" "$INPUT" "$TMPPATH/pref_step$STEP" "$TMPPATH/aln_step$STEP" ${ALIGNMENT0_PAR}
date --rfc-3339=seconds
mmseqs clust $INPUT "$TMPPATH/aln_step$STEP" "$TMPPATH/clu_step$STEP" ${CLUSTER0_PAR}
date --rfc-3339=seconds
awk '{ print $1 }' "$TMPPATH/clu_step$STEP.index" > "$TMPPATH/order_step$STEP"
mmseqs createsubdb "$TMPPATH/order_step$STEP" $INPUT "$TMPPATH/input_step1"

date --rfc-3339=seconds
# go down to 90% (this step is needed to create big clusters) 
STEP=1
INPUT="$TMPPATH/input_step1"
$RUNNER mmseqs prefilter "$INPUT" "$INPUT" "$TMPPATH/pref_step$STEP" ${PREFILTER1_PAR}
date --rfc-3339=seconds
$RUNNER mmseqs align "$INPUT" "$INPUT" "$TMPPATH/pref_step$STEP" "$TMPPATH/aln_step$STEP" ${ALIGNMENT1_PAR}
date --rfc-3339=seconds
mmseqs clust $INPUT "$TMPPATH/aln_step$STEP" "$TMPPATH/clu_step$STEP" ${CLUSTER1_PAR}

date --rfc-3339=seconds
# create database uniclust 90% (we need to merge redundancy, step_0 and step_1)
mmseqs mergeclusters "${SEQUENCE_DB}" $OUTDIR/uniclust90_$RELEASE \
    "$TMPPATH/clu_frag" "$TMPPATH/clu_redundancy" $TMPPATH/clu_step0 $TMPPATH/clu_step1
date --rfc-3339=seconds

awk '{ print $1 }' "$TMPPATH/clu_step$STEP.index" > "$TMPPATH/order_step$STEP"
mmseqs createsubdb "$TMPPATH/order_step$STEP" $INPUT "$TMPPATH/input_step2"
# now we cluster down to 30% sequence id to produce a 30% and 50% clustering
STEP=2
INPUT=$TMPPATH/input_step2
date --rfc-3339=seconds
$RUNNER mmseqs prefilter $INPUT $INPUT "$TMPPATH/pref_step$STEP" ${PREFILTER2_PAR}
date --rfc-3339=seconds
$RUNNER mmseqs align $INPUT $INPUT "$TMPPATH/pref_step$STEP" "$TMPPATH/aln_step$STEP" ${ALIGNMENT2_PAR}
date --rfc-3339=seconds

# cluster down to 50% 
mmseqs filterdb "$TMPPATH/aln_step$STEP" "$TMPPATH/aln_uniclust50" \
    --filter-column 3 --filter-regex '(0\.[5-9][0-9]{2}|1\.000)'
date --rfc-3339=seconds
mmseqs clust $INPUT "$TMPPATH/aln_uniclust50" "$TMPPATH/clu_uniclust50" ${CLUSTER2_PAR}
date --rfc-3339=seconds
mmseqs mergeclusters "${SEQUENCE_DB}" $OUTDIR/uniclust50_$RELEASE \
    "$TMPPATH/clu_frag" "$TMPPATH/clu_redundancy" $TMPPATH/clu_step0 $TMPPATH/clu_step1 $TMPPATH/clu_uniclust50
date --rfc-3339=seconds

STEP=2
INPUT=$TMPPATH/input_step2
# cluster down to 30% 
mmseqs clust $INPUT "$TMPPATH/aln_step$STEP" "$TMPPATH/clu_uniclust30" ${CLUSTER2_PAR}
date --rfc-3339=seconds
mmseqs mergeclusters "${SEQUENCE_DB}" $OUTDIR/uniclust30_$RELEASE \
    "$TMPPATH/clu_frag" "$TMPPATH/clu_redundancy" $TMPPATH/clu_step0 $TMPPATH/clu_step1 $TMPPATH/clu_uniclust30
date --rfc-3339=seconds

# generate uniclust final output: the _seed, _conensus und .tsv
# also generated the profiles needed for the uniboost
for i in 30 50 90; do
    $RUNNER mmseqs result2profile "${SEQUENCE_DB}" "${SEQUENCE_DB}" "$OUTDIR/uniclust${i}_${RELEASE}" "$TMPPATH/uniclust${i}_${RELEASE}_profile"
    ln -sf "${SEQUENCE_DB}_h" "$TMPPATH/uniclust${i}_${RELEASE}_profile_h"
    ln -sf "${SEQUENCE_DB}_h.index" "$TMPPATH/uniclust${i}_${RELEASE}_profile_h.index"
    ln -sf "${SEQUENCE_DB}_h" "$TMPPATH/uniclust${i}_${RELEASE}_profile_consensus_h"
    ln -sf "${SEQUENCE_DB}_h.index" "$TMPPATH/uniclust${i}_${RELEASE}_profile_consensus_h.index"

     #fixme: won't work with updating
	mmseqs mergedbs "$OUTDIR/uniclust${i}_${RELEASE}" "$TMPPATH/uniclust${i}_${RELEASE}_seed" "$OUTDIR/uniprot_db_h" "$OUTDIR/uniprot_db" --prefixes ">"
	rm -f "$TMPPATH/uniclust${i}_${RELEASE}_seed.index"

	sed -i 's/\x0//g' "$TMPPATH/uniclust${i}_${RELEASE}_seed"

	mmseqs summarizeheaders "${SEQUENCE_DB}_h" "${SEQUENCE_DB}_h" "$OUTDIR/uniclust${i}_${RELEASE}" "$TMPPATH/uniclust${i}_${RELEASE}_summary" --summary-prefix "uc${i}-${SHORTRELEASE}"
	mmseqs mergedbs "$OUTDIR/uniclust${i}_$RELEASE" "$TMPPATH/uniclust${i}_${RELEASE}_consensus" "$TMPPATH/uniclust${i}_${RELEASE}_summary" "$TMPPATH/uniclust${i}_${RELEASE}_profile_consensus" --prefixes ">"
	rm -f "$TMPPATH/uniclust${i}_${RELEASE}_consensus.index"
	sed -i 's/\x0//g' "$TMPPATH/uniclust${i}_${RELEASE}_consensus"

	mmseqs createtsv "${SEQUENCE_DB}" "${SEQUENCE_DB}" "$OUTDIR/uniclust${i}_$RELEASE" "$TMPPATH/uniclust${i}_$RELEASE.tsv"
    mv -f "$TMPPATH/uniclust${i}_${RELEASE}_seed" "$TMPPATH/uniclust${i}_${RELEASE}_seed.fasta"
    mv -f "$TMPPATH/uniclust${i}_${RELEASE}_consensus" "$TMPPATH/uniclust${i}_${RELEASE}_consensus.fasta"

	tar -cv --use-compress-program=pigz --show-transformed-names --transform "s|${TMPPATH:1}/|uniclust${i}_${RELEASE}/|g" -f "$OUTDIR/uniclust${i}_${RELEASE}.tar.gz" "$TMPPATH/uniclust${i}_$RELEASE.tsv" "$TMPPATH/uniclust${i}_${RELEASE}_consensus.fasta" "$TMPPATH/uniclust${i}_${RELEASE}_seed.fasta"
done

# create uniboost 
INPUT="$TMPPATH/uniclust30_${RELEASE}_profile"
TARGET="$TMPPATH/uniclust30_${RELEASE}_profile_consensus"
mkdir -p "$TMPPATH/boost1"
unset OMP_PROC_BIND
# Add homologous sequences to uniprot30 clusters using a profile search through the uniprot30 consensus sequences with 3 iterations
mmseqs search "$INPUT" "$TARGET" "$TMPPATH/boost1/aln_boost" "$TMPPATH/boost1" ${SEARCH_PAR} --num-iterations 4 --add-self-matches

TARGET="$TMPPATH/uniclust30_${RELEASE}_profile_consensus"
INPUT="$TARGET"
RESULT="$TMPPATH/boost1/aln_boost"

export OMP_PROC_BIND=true
## For each cluster generate an MSA with -qsc filter (score per column with query) of 0.0, 0.5 1.1.
$RUNNER mmseqs result2msa "$INPUT" "$TARGET" "$RESULT" "$OUTDIR/uniboost10_${RELEASE}" --qsc 0.0 --compress
mv "$OUTDIR/uniboost10_${RELEASE}_ca3m" "$OUTDIR/uniboost10_${RELEASE}_ca3m.ffdata"
mv "$OUTDIR/uniboost10_${RELEASE}_ca3m.index" "$OUTDIR/uniboost10_${RELEASE}_ca3m.ffindex"

awk '{ print $1 }' "${INPUT}.index" > "${INPUT}.list"
mmseqs createsubdb "${INPUT}.list" "${INPUT}" "${INPUT}_small_h"

for i in 10 20 30; do
    ln -sf "${INPUT}" "$OUTDIR/uniboost${i}_${RELEASE}_sequence.ffdata"
    ln -sf "${INPUT}.index" "$OUTDIR/uniboost${i}_${RELEASE}_sequence.ffindex"
    ln -sf "${INPUT}_small_h" "$OUTDIR/uniboost${i}_${RELEASE}_header.ffdata"
    ln -sf "${INPUT}_small_h.index" "$OUTDIR/uniboost${i}_${RELEASE}_header.ffindex"
done

mpirun cstranslate_mpi ${CSTRANSLATE_PAR} -i "$OUTDIR/uniboost10_${RELEASE}" -o "${TMPPATH}/uniboost_${RELEASE}_cs219" --both
$RUNNER mmseqs result2msa "$INPUT" "$TARGET" "$RESULT" "$OUTDIR/uniboost20_${RELEASE}" --qsc 0.5 --compress
$RUNNER mmseqs result2msa "$INPUT" "$TARGET" "$RESULT" "$OUTDIR/uniboost30_${RELEASE}" --qsc 1.1 --compress

for i in 20 30; do
    mv -f "$OUTDIR/uniboost${i}_${RELEASE}_ca3m" "$OUTDIR/uniboost${i}_${RELEASE}_ca3m.ffdata"
    mv -f "$OUTDIR/uniboost${i}_${RELEASE}_ca3m.index" "$OUTDIR/uniboost${i}_${RELEASE}_ca3m.ffindex"
done

for i in 10 20 30; do
    ln -sf "${TMPPATH}/uniboost_${RELEASE}_cs219_binary.ffdata"  "${OUTDIR}/uniboost${i}_${RELEASE}_cs219.ffdata"
    ln -sf "${TMPPATH}/uniboost_${RELEASE}_cs219_binary.ffindex" "${OUTDIR}/uniboost${i}_${RELEASE}_cs219.ffindex"
    
    ffindex_build -as "$OUTDIR/uniboost${i}_${RELEASE}_ca3m.ffdata" "$OUTDIR/uniboost${i}_${RELEASE}_ca3m.ffindex"
    ffindex_build -as "$OUTDIR/uniboost${i}_${RELEASE}_cs219.ffdata" "$OUTDIR/uniboost${i}_${RELEASE}_cs219.ffindex" 

    md5deep "$OUTDIR/uniboost${i}_${RELEASE}_ca3m.ffdata" "$OUTDIR/uniboost${i}_${RELEASE}_ca3m.ffindex" \
            "$OUTDIR/uniboost${i}_${RELEASE}_header.ffdata" "$OUTDIR/uniboost${i}_${RELEASE}_header.ffindex" \
            "$OUTDIR/uniboost${i}_${RELEASE}_sequence.ffdata" "$OUTDIR/uniboost${i}_${RELEASE}_sequence.ffindex" \
            "$OUTDIR/uniboost${i}_${RELEASE}_cs219.ffdata" "$OUTDIR/uniboost${i}_${RELEASE}_cs219.ffindex" > "$OUTDIR/uniboost${i}_${RELEASE}_md5sum"

    tar -cv --use-compress-program=pigz --dereference \
        --show-transformed-names --transform "s|${OUTDIR:1}/|uniboost${i}_${RELEASE}/|g" \
        -f "$OUTDIR/uniboost${i}_${RELEASE}.tar.gz" \
        "$OUTDIR/uniboost${i}_${RELEASE}_ca3m.ffdata" "$OUTDIR/uniboost${i}_${RELEASE}_ca3m.ffindex" \
        "$OUTDIR/uniboost${i}_${RELEASE}_header.ffdata" "$OUTDIR/uniboost${i}_${RELEASE}_header.ffindex" \
        "$OUTDIR/uniboost${i}_${RELEASE}_sequence.ffdata" "$OUTDIR/uniboost${i}_${RELEASE}_sequence.ffindex" \
        "$OUTDIR/uniboost${i}_${RELEASE}_cs219.ffdata" "$OUTDIR/uniboost${i}_${RELEASE}_cs219.ffindex" \
        "$OUTDIR/uniboost${i}_${RELEASE}_md5sum"
done

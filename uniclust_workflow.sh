#!/bin/bash -ex
[ -z "$MMDIR" ] && echo "Please set the environment variable \$MMDIR to your MMSEQS installation directory." && exit 1;
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

TMPDIR=$OUTDIR/tmp
mkdir -p $TMPDIR

OUTDIR=$(abspath $OUTDIR)
TMPDIR=$(abspath $TMPDIR)

PREFILTER_COMMON="$COMMON --diag-score 1 --min-ungapped-score 15 --spaced-kmer-mode 1 --max-seq-len 32768"
PREFILTER0_PAR="--max-seqs 20  --comp-bias-corr 0 --k-score 145 ${PREFILTER_COMMON}"
PREFILTER1_PAR="--max-seqs 100 --comp-bias-corr 1 --k-score 135 ${PREFILTER_COMMON}"
PREFILTER2_PAR="--max-seqs 300 --comp-bias-corr 1 --k-score 90 -k 6 ${PREFILTER_COMMON}"
ALIGNMENT_COMMON="$COMMON -e 0.001 --max-seq-len 32768 --max-rejected 2147483647"
ALIGNMENT0_PAR="--max-seqs 20  -c 0.9 --alignment-mode 2 --min-seq-id 0.9 --comp-bias-corr 0 --frag-merge ${ALIGNMENT_COMMON}"
ALIGNMENT1_PAR="--max-seqs 100 -c 0.9 --alignment-mode 2 --min-seq-id 0.9 --comp-bias-corr 1 ${ALIGNMENT_COMMON}"
ALIGNMENT2_PAR="--max-seqs 300 -c 0.8 --alignment-mode 3 --min-seq-id 0.3 --comp-bias-corr 1 ${ALIGNMENT_COMMON}"
CLUSTER0_PAR="--cluster-mode 2"
CLUSTER1_PAR="--cluster-mode 0"
CLUSTER2_PAR="--cluster-mode 0"
SEARCH_PAR="$COMMON --profile --k-score 100"
CSTRANSLATE_PAR="-x 0.3 -c 4 -A $HHLIB/data/cs219.lib -D $HHLIB/data/context_data.lib -I ca3m -f -b"

SEQUENCE_DB="$OUTDIR/uniprot_db"

export OMP_PROC_BIND=true

# we split all sequences that are above 14k in N/14k parts
mmseqs createdb "$INPUT" "${SEQUENCE_DB}" --max-seq-len 14000

date --rfc-3339=seconds
# filter redundancy 
INPUT="${SEQUENCE_DB}"
mmseqs clusthash $INPUT "$TMPDIR/aln_redundancy" --min-seq-id 0.9
date --rfc-3339=seconds
mmseqs clust $INPUT "$TMPDIR/aln_redundancy" "$TMPDIR/clu_redundancy" ${CLUSTER1_PAR}
date --rfc-3339=seconds
awk '{ print $1 }' "$TMPDIR/clu_redundancy.index" > "$TMPDIR/order_redundancy"
mmseqs createsubdb "$TMPDIR/order_redundancy" $INPUT "$TMPDIR/input_step0"

date --rfc-3339=seconds
# go down to 90% and merge fragments (accept fragment if dbcov >= 0.95 && seqId >= 0.9)
STEP=0
INPUT="$TMPDIR/input_step0"
$RUNNER mmseqs prefilter "$INPUT" "$INPUT" "$TMPDIR/pref_step$STEP" ${PREFILTER0_PAR}
date --rfc-3339=seconds
$RUNNER mmseqs align "$INPUT" "$INPUT" "$TMPDIR/pref_step$STEP" "$TMPDIR/aln_step$STEP" ${ALIGNMENT0_PAR}
date --rfc-3339=seconds
mmseqs clust $INPUT "$TMPDIR/aln_step$STEP" "$TMPDIR/clu_step$STEP" ${CLUSTER0_PAR}
date --rfc-3339=seconds
awk '{ print $1 }' "$TMPDIR/clu_step$STEP.index" > "$TMPDIR/order_step$STEP"
mmseqs createsubdb "$TMPDIR/order_step$STEP" $INPUT "$TMPDIR/input_step1"

date --rfc-3339=seconds
# go down to 90% (this step is needed to create big clusters) 
STEP=1
INPUT="$TMPDIR/input_step1"
$RUNNER mmseqs prefilter "$INPUT" "$INPUT" "$TMPDIR/pref_step$STEP" ${PREFILTER1_PAR}
date --rfc-3339=seconds
$RUNNER mmseqs align "$INPUT" "$INPUT" "$TMPDIR/pref_step$STEP" "$TMPDIR/aln_step$STEP" ${ALIGNMENT1_PAR}
date --rfc-3339=seconds
mmseqs clust $INPUT "$TMPDIR/aln_step$STEP" "$TMPDIR/clu_step$STEP" ${CLUSTER1_PAR}

date --rfc-3339=seconds
# create database uniclust 90% (we need to merge redundancy, step_0 and step_1)
mmseqs mergeclusters "${SEQUENCE_DB}" $OUTDIR/uniclust90_$RELEASE \
    "$TMPDIR/clu_redundancy" $TMPDIR/clu_step0 $TMPDIR/clu_step1
date --rfc-3339=seconds

awk '{ print $1 }' "$TMPDIR/clu_step$STEP.index" > "$TMPDIR/order_step$STEP"
mmseqs createsubdb "$TMPDIR/order_step$STEP" $INPUT "$TMPDIR/input_step2"

# now we cluster down to 30% sequence id to produce a 30% and 50% clustering
STEP=2
INPUT=$TMPDIR/input_step2
date --rfc-3339=seconds
$RUNNER mmseqs prefilter $INPUT $INPUT "$TMPDIR/pref_step$STEP" ${PREFILTER2_PAR}
date --rfc-3339=seconds
$RUNNER mmseqs align $INPUT $INPUT "$TMPDIR/pref_step$STEP" "$TMPDIR/aln_step$STEP" ${ALIGNMENT2_PAR}
date --rfc-3339=seconds

# cluster down to 50% 
mmseqs filterdb "$TMPDIR/aln_step$STEP" "$TMPDIR/aln_uniclust50" \
    --filter-column 3 --filter-regex '(0\.[5-9][0-9]{2}|1\.000)'
date --rfc-3339=seconds
mmseqs clust $INPUT "$TMPDIR/aln_uniclust50" "$TMPDIR/clu_uniclust50" ${CLUSTER2_PAR}
date --rfc-3339=seconds
mmseqs mergeclusters "${SEQUENCE_DB}" $OUTDIR/uniclust50_$RELEASE \
    "$TMPDIR/clu_redundancy" $TMPDIR/clu_step0 $TMPDIR/clu_step1 $TMPDIR/clu_uniclust50
date --rfc-3339=seconds

# cluster down to 30% 
mmseqs clust $INPUT "$TMPDIR/aln_step$STEP" "$TMPDIR/clu_uniclust30" ${CLUSTER2_PAR}
date --rfc-3339=seconds
mmseqs mergeclusters "${SEQUENCE_DB}" $OUTDIR/uniclust30_$RELEASE \
    "$TMPDIR/clu_redundancy" $TMPDIR/clu_step0 $TMPDIR/clu_step1 $TMPDIR/clu_uniclust30
date --rfc-3339=seconds

# generate uniclust final output: the _seed, _conensus und .tsv
# also generated the profiles needed for the uniboost
for i in 30 50 90; do
    $RUNNER mmseqs result2profile "${SEQUENCE_DB}" "${SEQUENCE_DB}" "$OUTDIR/uniclust${i}_${RELEASE}" "$TMPDIR/uniclust${i}_${RELEASE}_profile"
    ln -sf "${SEQUENCE_DB}_h" "$TMPDIR/uniclust${i}_${RELEASE}_profile_h"
    ln -sf "${SEQUENCE_DB}_h.index" "$TMPDIR/uniclust${i}_${RELEASE}_profile_h.index"
    ln -sf "${SEQUENCE_DB}_h" "$TMPDIR/uniclust${i}_${RELEASE}_profile_consensus_h"
    ln -sf "${SEQUENCE_DB}_h.index" "$TMPDIR/uniclust${i}_${RELEASE}_profile_consensus_h.index"

     #fixme: won't work with updating
	mmseqs mergedbs "$OUTDIR/uniclust${i}_${RELEASE}" "$TMPDIR/uniclust${i}_${RELEASE}_seed" "$OUTDIR/uniprot_db_h" "$OUTDIR/uniprot_db" --prefixes ">"
	rm -f "$TMPDIR/uniclust${i}_${RELEASE}_seed.index"

	sed -i 's/\x0//g' "$TMPDIR/uniclust${i}_${RELEASE}_seed"

	mmseqs summarizeheaders "${SEQUENCE_DB}_h" "${SEQUENCE_DB}_h" "$OUTDIR/uniclust${i}_${RELEASE}" "$TMPDIR/uniclust${i}_${RELEASE}_summary" --summary-prefix "uc${i}-${SHORTRELEASE}"
	mmseqs mergedbs "$OUTDIR/uniclust${i}_$RELEASE" "$TMPDIR/uniclust${i}_${RELEASE}_consensus" "$TMPDIR/uniclust${i}_${RELEASE}_summary" "$TMPDIR/uniclust${i}_${RELEASE}_profile_consensus" --prefixes ">"
	rm -f "$TMPDIR/uniclust${i}_${RELEASE}_consensus.index"
	sed -i 's/\x0//g' "$TMPDIR/uniclust${i}_${RELEASE}_consensus"

	mmseqs createtsv "${SEQUENCE_DB}" "${SEQUENCE_DB}" "$OUTDIR/uniclust${i}_$RELEASE" "$TMPDIR/uniclust${i}_$RELEASE.tsv"
    mv -f "$TMPDIR/uniclust${i}_${RELEASE}_seed" "$TMPDIR/uniclust${i}_${RELEASE}_seed.fasta"
    mv -f "$TMPDIR/uniclust${i}_${RELEASE}_consensus" "$TMPDIR/uniclust${i}_${RELEASE}_consensus.fasta"

	tar -cv --use-compress-program=pigz --show-transformed-names --transform "s|${TMPDIR:1}/|uniclust${i}_${RELEASE}/|g" -f "$OUTDIR/uniclust${i}_${RELEASE}.tar.gz" "$TMPDIR/uniclust${i}_$RELEASE.tsv" "$TMPDIR/uniclust${i}_${RELEASE}_consensus.fasta" "$TMPDIR/uniclust${i}_${RELEASE}_seed.fasta"
done

# create uniboost 
INPUT="$TMPDIR/uniclust30_${RELEASE}_profile"
TARGET="$TMPDIR/uniclust30_${RELEASE}_profile_consensus"
mkdir -p "$TMPDIR/boost1"
unset OMP_PROC_BIND
# Add homologous sequences to uniprot30 clusters using a profile search through the uniprot30 consensus sequences with 3 iterations
mmseqs search "$INPUT" "$TARGET" "$TMPDIR/boost1/aln_boost" "$TMPDIR/boost1" ${SEARCH_PAR} --num-iterations 3 --add-self-matches

RESULT="$TMPDIR/boost1/aln_boost"
$RUNNER mmseqs result2profile "$INPUT" "$TARGET" "$TMPDIR/boost1/aln_boost" "$TMPDIR/boost1/profile_2" $COMMON --profile
ln -s "${SEQUENCE_DB}_h" "$TMPDIR/boost1/profile_2_h"
ln -s "${SEQUENCE_DB}_h.index" "$TMPDIR/boost1/profile_2_h.index"

mkdir -p "$TMPDIR/boost2"
mmseqs search "$TMPDIR/boost1/profile_2" "$TMPDIR/boost1/profile_2_consensus" "$TMPDIR/boost2/aln_reverse" "$TMPDIR/boost2" ${SEARCH_PAR} --add-self-matches
$RUNNER mmseqs swapresults "$TMPDIR/boost1/profile_2" "$TMPDIR/boost1/profile_2_consensus" "$TMPDIR/boost2/aln_reverse" "$TMPDIR/boost2/aln_reverse_swapped"

INPUT=$TMPDIR/uniclust30_profile
ln -sf "${SEQUENCE_DB}_h" "$TMPDIR/boost1/profile_2_consensus_h"
ln -sf "${SEQUENCE_DB}_h.index" "$TMPDIR/boost1/profile_2_consensus_h.index"

INPUT="$TMPDIR/boost1/profile_2_consensus"
RESULT="$TMPDIR/boost2/aln_reverse_swapped"
TARGET="$INPUT"

export OMP_PROC_BIND=true
## For each cluster generate an MSA with -qsc filter (score per column with query) of 0.0, 0.5 1.1.
$RUNNER mmseqs result2msa "$INPUT" "$TARGET" "$RESULT" "$OUTDIR/uniboost10_${RELEASE}" --qsc 0.0 --compress
mv "$OUTDIR/uniboost10_${RELEASE}_ca3m" "$OUTDIR/uniboost10_${RELEASE}_ca3m.ffdata"
mv "$OUTDIR/uniboost10_${RELEASE}_ca3m.index" "$OUTDIR/uniboost10_${RELEASE}_ca3m.ffindex"
for i in 10 20 30; do
    ln -sf "${INPUT}" "$OUTDIR/uniboost${i}_${RELEASE}_sequence.ffdata"
    ln -sf "${INPUT}.index" "$OUTDIR/uniboost${i}_${RELEASE}_sequence.ffindex"
    ln -sf "${INPUT}_h" "$OUTDIR/uniboost${i}_${RELEASE}_header.ffdata"
    ln -sf "${INPUT}_h.index" "$OUTDIR/uniboost${i}_${RELEASE}_header.ffindex"
done
mpirun cstranslate_mpi ${CSTRANSLATE_PAR} -i "$OUTDIR/uniboost10_${RELEASE}" -o "${TMPDIR}/uniboost_${RELEASE}_cs219" --both
$RUNNER mmseqs result2msa "$INPUT" "$TARGET" "$RESULT" "$OUTDIR/uniboost20_${RELEASE}" --qsc 0.5 --compress
$RUNNER mmseqs result2msa "$INPUT" "$TARGET" "$RESULT" "$OUTDIR/uniboost30_${RELEASE}" --qsc 1.1 --compress

for i in 20 30; do
    mv -f "$OUTDIR/uniboost${i}_${RELEASE}_ca3m" "$OUTDIR/uniboost${i}_${RELEASE}_ca3m.ffdata"
    mv -f "$OUTDIR/uniboost${i}_${RELEASE}_ca3m.index" "$OUTDIR/uniboost${i}_${RELEASE}_ca3m.ffindex"
done

for i in 10 20 30; do
    ln -sf "${TMPDIR}/uniboost_${RELEASE}_cs219_binary.ffdata"  "${OUTDIR}/uniboost${i}_${RELEASE}_cs219.ffdata"
    ln -sf "${TMPDIR}/uniboost_${RELEASE}_cs219_binary.ffindex" "${OUTDIR}/uniboost${i}_${RELEASE}_cs219.ffindex"
	tar -cv --use-compress-program=pigz --dereference \
        --show-transformed-names --transform "s|${OUTDIR:1}/|uniboost${i}_${RELEASE}/|g" \
        -f "$OUTDIR/uniboost${i}_${RELEASE}.tar.gz" \
        "$OUTDIR/uniboost${i}_${RELEASE}_ca3m.ffdata" \
        "$OUTDIR/uniboost${i}_${RELEASE}_ca3m.ffdata" \
        "$OUTDIR/uniboost${i}_${RELEASE}_header.ffindex" \
        "$OUTDIR/uniboost${i}_${RELEASE}_header.ffindex" \
        "$OUTDIR/uniboost${i}_${RELEASE}_sequence.ffindex" \
        "$OUTDIR/uniboost${i}_${RELEASE}_sequence.ffindex" \
        "$OUTDIR/uniboost${i}_${RELEASE}_cs219.ffindex" \
        "$OUTDIR/uniboost${i}_${RELEASE}_cs219.ffindex"
done

#!/bin/bash -ex
[ "$#" -lt 2  ] && echo "Please provide <sequenceDB> <outDir>"  && exit 1;
[ ! -f "$1"   ] && echo "Sequence database $1 not found!"       && exit 1;
#[   -d "$2"   ] && echo "Output directory $2 exists already!"   && exit 1;

source uniclust/make_fasta.sh

RELEASE="${3:-$(date "+%Y_%m")}"
SHORTRELEASE="${4:-$(date "+%y%m")}"

INPUT="$1"
OUTDIR="$2/$RELEASE"

TMPPATH="$OUTDIR/tmp"
mkdir -p "$TMPPATH"

OUTDIR="$(abspath $OUTDIR)"
TMPPATH="$(abspath $TMPPATH)"

PREFILTER_COMMON="$COMMON"
PREFILTER_FRAG_PAR="--max-seqs 4000 --min-ungapped-score 100 --comp-bias-corr 0 -s 1 ${PREFILTER_COMMON}"
PREFILTER1_PAR="--max-seqs 100 -c 0.9 --comp-bias-corr 1 -s 2 ${PREFILTER_COMMON}"
PREFILTER2_PAR="--max-seqs 300 -c 0.8 --comp-bias-corr 1 -s 6  ${PREFILTER_COMMON}"
ALIGNMENT_COMMON="$COMMON -e 0.001 --max-seq-len 32768"
ALIGNMENT0_PAR="--max-seqs 100 -c 0.9 --alignment-mode 2 --min-seq-id 0.9 --comp-bias-corr 0 ${ALIGNMENT_COMMON}"
ALIGNMENT1_PAR="--max-seqs 100 -c 0.9 --alignment-mode 2 --min-seq-id 0.9 --comp-bias-corr 1 ${ALIGNMENT_COMMON}"
ALIGNMENT2_PAR="--max-seqs 300 -c 0.8 --alignment-mode 3 --min-seq-id 0.3 --comp-bias-corr 1 ${ALIGNMENT_COMMON}"
CLUSTER_FRAG_PAR="--cluster-mode 2"
CLUSTER0_PAR="--cluster-mode 2"
CLUSTER1_PAR="--cluster-mode 0"
CLUSTER2_PAR="--cluster-mode 0"
SEARCH_PAR="$COMMON --k-score 100"
CSTRANSLATE_PAR="-x 0.3 -c 4 -A $HHLIB/data/cs219.lib -D $HHLIB/data/context_data.lib -I ca3m -f -b"

SEQUENCE_DB="$OUTDIR/uniprot_db"

function notExists() {
    [ ! -f "$1" ]
}

# we split all sequences that are above 14k in N/14k parts
if notExists "${SEQUENCE_DB}"; then
    mmseqs createdb "$INPUT" "${SEQUENCE_DB}" --max-seq-len 14000
fi

##
# Build the Uniclust
##

# Fragment filtering
STEP="_FRAG"
INPUT="${SEQUENCE_DB}"
if notExists "$TMPPATH/pref_step$STEP"; then
    date --rfc-3339=seconds
    $RUNNER mmseqs prefilter "$INPUT" "$INPUT" "$TMPPATH/pref_step$STEP" ${PREFILTER_FRAG_PAR}
fi
if notExists "$TMPPATH/aln_step$STEP"; then
    date --rfc-3339=seconds
    mmseqs rescorediagonal  "$INPUT" "$INPUT" "$TMPPATH/pref_step$STEP" "$TMPPATH/aln_step$STEP" --min-seq-id 0.9 -c 0.95 --cov-mode 1
fi
if notExists "$TMPPATH/clu_frag"; then
    date --rfc-3339=seconds
    mmseqs clust $INPUT "$TMPPATH/aln_step$STEP" "$TMPPATH/clu_frag" ${CLUSTER_FRAG_PAR}
fi

if notExists "$TMPPATH/input_step_redundancy"; then
    date --rfc-3339=seconds
    awk '{ print $1 }' "$TMPPATH/clu_frag.index" > "$TMPPATH/order_frag"
    mmseqs createsubdb "$TMPPATH/order_frag" $INPUT "$TMPPATH/input_step_redundancy"
fi

# filter redundancy 
INPUT="$TMPPATH/input_step_redundancy"
if notExists "$TMPPATH/aln_redundancy"; then
    date --rfc-3339=seconds
    mmseqs clusthash $INPUT "$TMPPATH/aln_redundancy" --min-seq-id 0.9
fi
if notExists "$TMPPATH/clu_redundancy"; then
    date --rfc-3339=seconds
    mmseqs clust $INPUT "$TMPPATH/aln_redundancy" "$TMPPATH/clu_redundancy" ${CLUSTER_FRAG_PAR}
fi
if notExists "$TMPPATH/input_step0"; then
    date --rfc-3339=seconds
    awk '{ print $1 }' "$TMPPATH/clu_redundancy.index" > "$TMPPATH/order_redundancy"
    mmseqs createsubdb "$TMPPATH/order_redundancy" $INPUT "$TMPPATH/input_step0"
fi

# go down to 90%
STEP=0
INPUT="$TMPPATH/input_step0"
# Remove the fragments from the prefilter, in order not to recompute prefilter
if notExists "$TMPPATH/pref_step$STEP"; then
    date --rfc-3339=seconds
    mmseqs createsubdb  "$TMPPATH/order_redundancy"  "$TMPPATH/pref_step_FRAG"  "$TMPPATH/pref_step_FRAG_filtered"
    mmseqs filterdb "$TMPPATH/pref_step_FRAG_filtered" "$TMPPATH/pref_step$STEP" --filter-file "$TMPPATH/order_redundancy"
fi
if notExists "$TMPPATH/aln_step$STEP"; then
    date --rfc-3339=seconds
    $RUNNER mmseqs align "$INPUT" "$INPUT" "$TMPPATH/pref_step$STEP" "$TMPPATH/aln_step$STEP" ${ALIGNMENT0_PAR}
fi
if notExists "$TMPPATH/clu_step$STEP"; then
    date --rfc-3339=seconds
    mmseqs clust $INPUT "$TMPPATH/aln_step$STEP" "$TMPPATH/clu_step$STEP" ${CLUSTER0_PAR}
fi
if notExists "$TMPPATH/input_step1"; then
    date --rfc-3339=seconds
    awk '{ print $1 }' "$TMPPATH/clu_step$STEP.index" > "$TMPPATH/order_step$STEP"
    mmseqs createsubdb "$TMPPATH/order_step$STEP" $INPUT "$TMPPATH/input_step1"
fi

# go down to 90% (this step is needed to create big clusters) 
STEP=1
INPUT="$TMPPATH/input_step1"
if notExists "$TMPPATH/pref_step$STEP"; then
    date --rfc-3339=seconds
    $RUNNER mmseqs prefilter "$INPUT" "$INPUT" "$TMPPATH/pref_step$STEP" ${PREFILTER1_PAR}
fi
if notExists "$TMPPATH/aln_step$STEP"; then
    date --rfc-3339=seconds
    $RUNNER mmseqs align "$INPUT" "$INPUT" "$TMPPATH/pref_step$STEP" "$TMPPATH/aln_step$STEP" ${ALIGNMENT1_PAR}
fi
if notExists "$TMPPATH/clu_step$STEP"; then
    date --rfc-3339=seconds
    mmseqs clust $INPUT "$TMPPATH/aln_step$STEP" "$TMPPATH/clu_step$STEP" ${CLUSTER1_PAR}
fi

# create database uniclust 90% (we need to merge redundancy, step_0 and step_1)
if notExists "$OUTDIR/uniclust90_$RELEASE"; then
    date --rfc-3339=seconds
    mmseqs mergeclusters "${SEQUENCE_DB}" "$OUTDIR/uniclust90_$RELEASE" \
        "$TMPPATH/clu_frag" "$TMPPATH/clu_redundancy" "$TMPPATH/clu_step0" "$TMPPATH/clu_step1"
fi

if notExists "$TMPPATH/input_step2"; then
    date --rfc-3339=seconds
    awk '{ print $1 }' "$TMPPATH/clu_step$STEP.index" > "$TMPPATH/order_step$STEP"
    mmseqs createsubdb "$TMPPATH/order_step$STEP" "$INPUT" "$TMPPATH/input_step2"
fi

# now we cluster down to 30% sequence id to produce a 30% and 50% clustering
STEP=2
INPUT=$TMPPATH/input_step2
if notExists "$TMPPATH/pref_step$STEP"; then
    date --rfc-3339=seconds
    $RUNNER mmseqs prefilter "$INPUT" "$INPUT" "$TMPPATH/pref_step$STEP" ${PREFILTER2_PAR}
fi
if notExists "$TMPPATH/aln_step$STEP"; then
    date --rfc-3339=seconds
    $RUNNER mmseqs align "$INPUT" "$INPUT" "$TMPPATH/pref_step$STEP" "$TMPPATH/aln_step$STEP" ${ALIGNMENT2_PAR}
fi

# cluster down to 50% 
if notExists "$TMPPATH/aln_uniclust50"; then
    date --rfc-3339=seconds
    mmseqs filterdb "$TMPPATH/aln_step$STEP" "$TMPPATH/aln_uniclust50" \
        --filter-column 3 --filter-regex '(0\.[5-9][0-9]{2}|1\.000)'
fi
if notExists "$TMPPATH/clu_uniclust50"; then
    date --rfc-3339=seconds
    mmseqs clust $INPUT "$TMPPATH/aln_uniclust50" "$TMPPATH/clu_uniclust50" ${CLUSTER2_PAR}
fi
if notExists "$OUTDIR/uniclust50_$RELEASE"; then
    date --rfc-3339=seconds
    mmseqs mergeclusters "${SEQUENCE_DB}" "$OUTDIR/uniclust50_$RELEASE" \
        "$TMPPATH/clu_frag" "$TMPPATH/clu_redundancy" "$TMPPATH/clu_step0" "$TMPPATH/clu_step1" "$TMPPATH/clu_uniclust50"
fi

STEP=2
INPUT=$TMPPATH/input_step2
# cluster down to 30% 
if notExists "$TMPPATH/clu_uniclust30"; then
    date --rfc-3339=seconds
    mmseqs clust $INPUT "$TMPPATH/aln_step$STEP" "$TMPPATH/clu_uniclust30" ${CLUSTER2_PAR}
fi
if notExists "$OUTDIR/uniclust30_$RELEASE"; then
    date --rfc-3339=seconds
    mmseqs mergeclusters "${SEQUENCE_DB}" "$OUTDIR/uniclust30_$RELEASE" \
        "$TMPPATH/clu_frag" "$TMPPATH/clu_redundancy" "$TMPPATH/clu_step0" "$TMPPATH/clu_step1" "$TMPPATH/clu_uniclust30"
fi

# generate uniclust final output: the _seed, _conensus und .tsv
# also generates the profiles needed for the uniboost inside here
for i in 30 50 90; do
    if notExists "$OUTDIR/uniclust${i}_${RELEASE}.tar.gz"; then
        date --rfc-3339=seconds
        make_fasta $i $RELEASE $SHORTRELEASE "${SEQUENCE_DB}" "$OUTDIR/uniclust${i}_${RELEASE}" "$TMPPATH"
        make_fasta_archive $i $RELEASE "${SEQUENCE_DB}" "$OUTDIR/uniclust${i}_${RELEASE}" "$OUTDIR" "$TMPPATH"
    fi
done

##
# Create Uniboost 
##
INPUT="$TMPPATH/uniclust30_${RELEASE}_profile"
TARGET="$TMPPATH/uniclust50_${RELEASE}_profile_consensus"
RESULT="$TMPPATH/aln_boost"
mkdir -p "$TMPPATH/boost"
if notExists "${RESULT}"; then
    # Add homologous sequences to uniprot30 clusters using a profile search through the uniprot30 consensus sequences with 4 iterations
    mmseqs search "$INPUT" "$TARGET" "${RESULT}" "$TMPPATH/boost" ${SEARCH_PAR} --num-iterations 4 --add-self-matches
fi


INPUT="$TMPPATH/uniclust30_${RELEASE}_profile_consensus"
## For each cluster generate an MSA with -qsc filter (score per column with query) of 0.0, 0.5 1.1.
if notExists "$OUTDIR/uniboost10_${RELEASE}_ca3m.ffdata"; then
    $RUNNER mmseqs result2msa "$INPUT" "$TARGET" "$RESULT" "$OUTDIR/uniboost10_${RELEASE}" --qsc 0.0 --compress
fi

if notExists "${INPUT}_small_h"; then
    awk '{ print $1 }' "${INPUT}.index" > "${INPUT}.list"
    mmseqs createsubdb "${INPUT}.list" "${INPUT}" "${INPUT}_small_h"
fi

if false; then
for i in 10 20 30; do
    ln -sf "${INPUT}" "$OUTDIR/uniboost${i}_${RELEASE}_sequence.ffdata"
    ln -sf "${INPUT}.index" "$OUTDIR/uniboost${i}_${RELEASE}_sequence.ffindex"
    ln -sf "${INPUT}_small_h" "$OUTDIR/uniboost${i}_${RELEASE}_header.ffdata"
    ln -sf "${INPUT}_small_h.index" "$OUTDIR/uniboost${i}_${RELEASE}_header.ffindex"
done
fi

if notExists "${TMPPATH}/uniboost_${RELEASE}_cs219.ffdata"; then
    OMP_NUM_THREADS=1 mpirun cstranslate_mpi ${CSTRANSLATE_PAR} -i "$OUTDIR/uniboost10_${RELEASE}" -o "${TMPPATH}/uniboost_${RELEASE}_cs219"
fi

if notExists "$OUTDIR/uniboost20_${RELEASE}_ca3m.ffdata"; then
    $RUNNER mmseqs result2msa "$INPUT" "$TARGET" "$RESULT" "$OUTDIR/uniboost20_${RELEASE}" --qsc 0.5 --compress
fi
if notExists "$OUTDIR/uniboost30_${RELEASE}_ca3m.ffindex"; then
    $RUNNER mmseqs result2msa "$INPUT" "$TARGET" "$RESULT" "$OUTDIR/uniboost30_${RELEASE}" --qsc 1.1 --compress
fi

for i in 10 20 30; do
    if notExists "$OUTDIR/uniboost${i}_${RELEASE}.tar.gz"; then
        # We use the cs219 from the Uniboost10 for the other two databases, since its the most diverse
        ln -sf "${TMPPATH}/uniboost_${RELEASE}_cs219.ffdata"  "${OUTDIR}/uniboost${i}_${RELEASE}_cs219.ffdata"
        ln -sf "${TMPPATH}/uniboost_${RELEASE}_cs219.ffindex" "${OUTDIR}/uniboost${i}_${RELEASE}_cs219.ffindex"

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
    fi
done

##
# Lookup from internal id to uniprot accession
##
if notExists "$OUTDIR/uniclust_uniprot_mapping.tsv.gz"; then
    pigz -c "$OUTDIR/uniprot_db.lookup" > "$OUTDIR/uniclust_uniprot_mapping.tsv.gz"
fi

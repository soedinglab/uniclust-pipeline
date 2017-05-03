#!/usr/bin/env python
import sys
import os
import collections

from ete3 import NCBITaxa
from ffindex import read_index, read_data, read_entry_data, finish_db, write_entry
from mpi4py import MPI
from subprocess import call

def taxonomy(taxa, ncbi):
    try:
        tree = ncbi.get_topology(taxa, rank_limit="species")
    except KeyError:
        sys.stderr.write("!")
        sys.stderr.flush()
        newTaxa = []
        for t in taxa:
            try:
                if len(ncbi.get_taxid_translator([t])) != 1:
                    continue
            except KeyError:
                continue

            newTaxa.append(t)
        tree = ncbi.get_topology(newTaxa, rank_limit="species")

    return tree.write(features=["sci_name"], format=1)

domain = collections.namedtuple('Domain', ['start', 'size'])

def decomposeDomain(domain_size, world_rank, world_size):
    if world_size > domain_size:
        sys.stderr.write("World Size: " + world_size + " aaSize: " + domain_size + "\n")
        sys.exit(1)

    subdomain_start = domain_size / world_size * world_rank;
    subdomain_size = domain_size / world_size;
    if world_rank == world_size - 1:
        subdomain_size += domain_size % world_size;

    return domain(subdomain_start, subdomain_size)

def main(dbIn, dbOut, lookupFile):
    comm = MPI.COMM_WORLD
    mpiSize = comm.Get_size()
    mpiRank = comm.Get_rank()

    data = read_data(dbIn)
    entries = read_index(dbIn + ".index")
    d = decomposeDomain(len(entries), mpiRank, mpiSize)

    lookup = {}
    cnt = 0
    with open(lookupFile) as f:
        for line in f:
            if mpiRank == 0 and cnt % 100000 == 0 and cnt > 0:
                sys.stdout.write('.')
                sys.stdout.flush()
            i, ox = line.split("\t")
            lookup[int(i)] = ox
            cnt += 1

    ncbi = NCBITaxa()

    sys.stdout.write("\n")

    outEntries = []
    outData = open(dbOut + "_"  + str(mpiRank), "w")

    offset = 0
    cnt = 0
    for i in xrange(d.start, d.start + d.size):
        entry = entries[i]
        if mpiRank == 0 and cnt % 100000 == 0 and cnt > 0:
            sys.stdout.write('.')
            sys.stdout.flush()

        ids = read_entry_data(entry, data);
        taxa = set()
        for s in ids.splitlines():
            key = int(s.strip())
            if key in lookup and lookup[key] != '':
                taxa.add(lookup[key])

        tree = ""
        if len(taxa) > 1:
            tree = taxonomy(taxa, ncbi)

        offset = write_entry(outEntries, outData, entry.name, offset, tree)

        cnt += 1

    finish_db(outEntries, dbOut + ".index_" + str(mpiRank), outData)

    comm.Barrier()
    if mpiRank == 0:
        for i in xrange(0, mpiSize):
            command = "ffindex_build -as %s %s -d %s -i %s" % (dbOut, dbOut + ".index", dbOut + "_"  + str(i), dbOut + ".index_" + str(i))
            call(command, shell=True)
            os.remove(dbOut + "_"  + str(i))
            os.remove(dbOut + ".index_" + str(i))

if __name__ == "__main__":
    if len(sys.argv) < 4:
        sys.stderr.write("Please provide <clusteringDBIn> <taxonomyDBOut> <lookupFile> \n")
        sys.exit(1)

    _, dbIn, dbOut, lookup = sys.argv

    if not os.path.isfile(dbIn):
        sys.stderr.write("<clusteringDBIn> " + dbIn + " does not exist!\n")
        sys.exit(1)

    if os.path.isfile(dbOut):
        sys.stderr.write("<taxonomyDBOut> " + dbOut + " does already exist!\n")
        sys.exit(1)

    if not os.path.isfile(lookup):
        sys.stderr.write("<lookupFile> " + lookup + " does not exist!\n")
        sys.exit(1)

    main(dbIn, dbOut, lookup)


#!/usr/bin/env python

import ffindex
import sys

input_file = sys.argv[1]
output_file = sys.argv[2]

entries = ffindex.read_index(input_file+".ffindex")
data = ffindex.read_data(input_file+".ffdata")

with open(output_file, "w") as fh:
    for entry in entries:
        size = int(ffindex.read_entry_data(entry, data).decode("utf-8"))
        if size < 51:
            fh.write(entry.name+"\n")

    

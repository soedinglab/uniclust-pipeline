#!/usr/bin/env python3

import ffindex
import sys

def main():
    input_database_basename = sys.argv[1]
    output_database_basename = sys.argv[2]

    input_data = ffindex.read_data(input_database_basename+".ffdata")
    input_index = ffindex.read_index(input_database_basename+".ffindex")

    fh = open(output_database_basename+".cs219", "wb")

    total_length = 0
    nr_sequences = len(input_index)
    line_break = bytearray("\n", "utf-8")[0]

    for entry in input_index:
        entry_data = ffindex.read_entry_data(entry, input_data)
        for i in range(len(entry_data)):
            if entry_data[i] == line_break:
                entry_data = entry_data[(i+1):]
                break
        total_length += len(entry_data)
        fh.write(bytearray(">"+entry.name+"\n", "utf-8"))
        fh.write(entry_data)
		
    fh.close()

    fh = open(output_database_basename+".cs219.sizes", "w")
    fh.write(str(nr_sequences) + " " + str(total_length))
    fh.close()

main()

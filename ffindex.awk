#!/home/mpg05/mmirdit/.linuxbrew/bin/gawk -f
BEGIN {
    last="";
    data="";
    offset=0;

    if (length(outfile) == 0) {
        outfile="output";
    }
    outindex=outfile".index";

    printf("") > outfile;
    printf("") > outindex;
}

NR == 1 {
    last=$1;
}

($1 != last) && (NR > 1) {
    printf "%s\0", data >> outfile;
    size=length(data)+1;

    print last"\t"offset"\t"size >> outindex;
    offset=offset+size;
    last=$1;
    data="";
}

{
    row=$2"\t"$3"\t"$4"\t"$6"\t"$7"\t"$9"\n"
    data=data""row;
}

END {
    close(outfile);
    close(outfile".index");

    system("ffindex_build -as "outfile" "outindex);
}

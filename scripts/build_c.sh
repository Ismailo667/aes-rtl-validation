#! /bin/bash
MGLS_INCLUDE=`which vsim | sed 's/\(.*\)bin.*/\1include/g' `
g++ -g -DDPI -I . -I $MGLS_INCLUDE  -shared -Bsymbolic -fpic TP/client.cc -o  TP/client.so


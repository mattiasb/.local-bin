#!/bin/bash
# This script reads all current GSettings values and prints out
# corresponding "gsettings set" lines
# Needs libglib2.0-bin, bash, awk
# Thanks to http://www.burtonini.com/blog/computers/gsettings-override-2011-07-04-15-45
# Copyright: nodiscc <nodiscc@gmail.com>,
#            Mattias Bengtsson <mattias.jc.bengtsson@gmail.com>
# License: CC-BY-SA

#Create override file
gsettings list-schemas | while read SCHEMA; do
    gsettings list-recursively $SCHEMA 2>/dev/null | awk '{ print "gsettings set SCHEMA " $2 " \"" $3 $4 $5 $6 $7 $8 $9 $10 $11 $12 $13 $14 $15 $16 $17 $18 $19 $20 $21 $22 $23 $24 $25 $26 $27 $28 $29 $30 $31 $32 $33 $34 $35 $36 $37 $38 $39 $40 "\""}' | m4 -DSCHEMA="${SCHEMA}" 
done

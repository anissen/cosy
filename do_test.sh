#!/bin/bash

filename=$1
optionsFile=../test/scripts/$filename.options
options=""
if [ -f $optionsFile ]; then
    options="$(cat $optionsFile)"
fi
./run.sh $options $filename 2>&1 | diff $filename.stdout -

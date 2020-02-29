#!/bin/bash

filename=$1
optionsFile=../test/scripts/$filename.options
options=""
echo -ne "\033[0;35m"
if [ -f $optionsFile ]; then
    options="$(cat $optionsFile)"
    echo "==> Validating '$filename $options'"
else
    echo "==> Validating '$filename'"
fi
echo -ne "\033[0m"
echo -ne "\033[0;31m"
# use 2>&1 to redirect stderr into stdout
# hl bin/cosy.hl $options ../test/scripts/$filename 2>&1 | diff ../test/scripts/$filename.stdout -
#hl bin/hl/cosy.hl $filename 2>&1 | diff $filename.stdout -
./scripts/run.sh $filename 2>&1 | diff --unified=0 $filename.stdout -
retVal=$?
echo -ne "\033[0m"

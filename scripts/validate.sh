#!/bin/bash

filename=$1
optionsFile=$filename.options
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
# hl bin/hl/cosy.hl --no-colors $options $filename 2>&1 | diff --unified=0 $filename.stdout -
# node bin/node/cosy.js  --no-colors $options $filename 2>&1 | diff --unified=0 $filename.stdout -
./scripts/run.sh --no-colors $options $filename 2>&1 | diff --unified=0 $filename.stdout -
retVal=$?
echo -ne "\033[0m"

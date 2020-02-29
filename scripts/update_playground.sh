#!/bin/bash

haxe scripts/javascript.hxml
retVal=$?
if [ $retVal -ne 0 ]; then
    echo -ne "\033[0;31m"
    echo "Compilation failed"
    echo -ne "\033[0m"
    exit $retVal
fi
cp bin/js/cosy.js docs/playground/cosy.js
cp test/examples/cosy-basics.cosy docs/playground/examples/ex-cosy-basics.cosy

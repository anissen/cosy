#!/bin/bash

echo -ne "\033[0;34m"
echo "> Compiling cosy..."
haxe build.hxml

echo -ne "\033[0;35m"
echo "> Validating"
echo -ne "\033[0m"

for filename in test/scripts/*.cosy; do
    [ -f "$filename" ] || break
    optionsFile=$filename.options
    options=""
    echo -ne "\033[0;35m"
    if [ -f $optionsFile ]; then
        options="$(cat $optionsFile)"
        echo "==> Validating '$options $filename'"
    else
        echo "==> Validating '$filename'"
    fi
    echo -ne "\033[0m"
    echo -ne "\033[0;31m"
    # use 2>&1 to redirect stderr into stdout
    # hl bin/cosy.hl $options ../test/scripts/$filename 2>&1 | diff ../test/scripts/$filename.stdout -
    #hl bin/hl/cosy.hl $filename 2>&1 | diff $filename.stdout -
    java -jar bin/java/cosy.jar $options $filename 2>&1 | diff $filename.stdout -
    retVal=$?
    echo -ne "\033[0m"
    # if [ $retVal -ne 0 ]; then
    #     echo -ne "\033[0;31m"
    #     echo "====> Error in $filename"
    #     echo -ne "\033[0m"
    #     #exit $retVal
    # else
    #     echo -ne "\033[0;32m"
    #     echo "OK!"
    #     echo -ne "\033[0m"
    # fi
done

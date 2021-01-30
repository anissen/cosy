#!/bin/bash

echo -ne "\033[0;34m"
echo "> Compiling cosy..."
haxe build.hxml
retVal=$?
if [ $retVal -ne 0 ]; then
    echo -ne "\033[0;31m"
    echo "Compilation failed"
    echo -ne "\033[0m"
    exit $retVal
fi

echo -ne "\033[0;35m"
echo "> Validating"
echo -ne "\033[0m"

fileglobs=(
    "test/scripts/*.cosy"
    "test/examples/99-bottles/*.cosy"
    "test/examples/advent-of-code-2020/*.cosy"
    "test/examples/misc/*.cosy"
)
for filename in ${fileglobs[@]}; do
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
    # hl bin/hl/Cosy.hl --no-colors $options $filename 2>&1 | diff --unified=0 $filename.stdout -
    java -jar bin/jvm/Cosy.jar --no-colors $options $filename 2>&1 | diff --unified=0 $filename.stdout -
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

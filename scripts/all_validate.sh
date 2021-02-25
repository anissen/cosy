#!/bin/bash
echo -ne "\033[0;34m"
echo "> Compiling cosy..."
# haxe scripts/jvm.hxml
haxe scripts/node.hxml
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

numberOfFiles=0
validFiles=0
fileglobs=(
    "test/scripts/*.cosy"
    "test/examples/99-bottles/*.cosy"
    "test/examples/advent-of-code-2020/*.cosy"
    "test/examples/misc/*.cosy"
)
validate () {
    for filename in ${fileglobs[@]}; do
        [ -f "$filename" ] || break
        let numberOfFiles++
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
        before=$SECONDS
        # hashlink c++: ./bin/hlc/Cosy
        # hashlink vm:  hl bin/hl/Cosy.hl
        # jvm:          java -jar bin/jvm/Cosy.jar
        # node:         node bin/node/cosy.js
        node bin/node/cosy.js --no-colors $options $filename 2>&1 | diff --unified=0 $filename.stdout -
        retVal=$?
        if [ $SECONDS -gt $((before+1)) ]; then # TODO: This is a *very* crude test for execution time of tests!
            echo "... SLOW!"
        fi
        if [ $retVal == 0 ]; then
            let validFiles++
        fi
        echo -ne "\033[0m"
    done
}
time validate
if [ $validFiles == $numberOfFiles ]; then
    echo -ne "\033[0;34m"
else
    echo -ne "\033[0;31m"
fi
echo "> $validFiles/$numberOfFiles are valid"
echo -ne "\033[0m"
numberOfInvalidFiles=$((numberOfFiles - validFiles))

exit $numberOfInvalidFiles
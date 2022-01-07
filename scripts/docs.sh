#!/bin/bash

haxe \
    -main cosy.Cosy \
    -cp src \
    -xml docs/docs.xml \
    -D doc-gen

rm -rf docs/api

haxelib run dox \
    --input-path docs/docs.xml \
    --output-path docs/api \
    --include cosy \
    --title "Cosy API Reference" \
    --toplevel-package cosy \
    -D website "https://github.com/anissen/cosy" \
    -D source-path "https://github.com/anissen/cosy/tree/master/src/" \
    -D logo "cosy-logo.svg"

rm docs/docs.xml

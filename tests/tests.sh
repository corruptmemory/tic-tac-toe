#!/usr/bin/env bash

ODIN=../../Odin/odin

for x in *_test.odin; do
    echo "---- Build - $x:"
    ${ODIN} build "$x" -collection:shared=../external
    echo "---- Test - $x:"
    ./${x%.odin}
    rm -f ${x%.odin}
    echo "      --------     "
done

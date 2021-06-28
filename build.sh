#!/usr/bin/env bash

export PATH="/big-disk/llvm11/bin$PATH"
export LD_LIBRARY_PATH="/big-disk/llvm11/lib:$LD_LIBRARY_PATH"
rm -f shaders/*.spv
rm -f tic-tac-toe
for x in shaders/*.vert shaders/*.frag; do
  out="$(basename $x | sed 's/\./-/g').spv"
  glslc $x -o shaders/$out
done
./odinc build tic-tac-toe.odin

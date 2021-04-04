#!/usr/bin/env bash
rm -f shaders/*.spv
rm -f tic-tac-toe
for x in shaders/*.vert shaders/*.frag; do
  out="$(basename $x | sed 's/\./-/g').spv"
  glslc $x -o shaders/$out
done
./odinc build tic-tac-toe.odin

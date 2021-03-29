#!/usr/bin/env bash
set -x
rm -f shaders/*.spv
rm -f tic-tac-toe
glslc shaders/shader.vert -o shaders/vert.spv
glslc shaders/shader.frag -o shaders/frag.spv
./odinc build tic-tac-toe.odin

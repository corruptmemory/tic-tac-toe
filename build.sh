#!/usr/bin/env bash

rm -f shaders/*.spv
glslc shaders/shader.vert -o shaders/vert.spv
glslc shaders/shader.frag -o shaders/frag.spv
./odinc build tic-tac-toe.odin

ODIN:=../Odin/odin

.PHONY: build clean

build: tic-tac-toe

# shaders/vert.spv: shaders/shader.vert
# 	glslc shaders/shader.vert -o shaders/vert.spv

# shaders/frag.spv: shaders/shader.frag
# 	glslc shaders/shader.frag -o shaders/frag.spv

tic-tac-toe: tic-tac-toe.odin
	$(ODIN) build tic-tac-toe.odin -vet -collection:shared=./external

run:
	$(ODIN) run tic-tac-toe.odin -vet -collection:shared=./external

clean:
	rm -f shaders/*.spv
	rm -f tic-tac-toe
	rm -f tic-tac-toe.ll tic-tac-toe.o tic-tac-toe.bc

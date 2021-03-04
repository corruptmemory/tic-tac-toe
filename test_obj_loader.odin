package main

import "core:log"
import "core:fmt"
import "wavefront"

main :: proc() {
  context.logger = log.create_console_logger(lowest = log.Level.Debug);
  go: wavefront.Wavefront_Object_File;
  wavefront.init_wavefront_object_file(&go);
  defer wavefront.destroy_wavefront_object_file(&go);
  ok := wavefront.wavefront_object_file_load_file(&go, "/home/jim/projects/tic-tac-toe/blender/donut.obj");
  fmt.printf("ok: %v -- go: %v\n", ok, go);
}

package wavefront

import "core:log"
import "core:os"

init_wavefront_object_file :: proc(object: ^Wavefront_Object_File) {
  object.mtllibs = make([dynamic]string);
  object.objects = make([dynamic]Wavefront_Object);
}

wavefront_object_file_load_file :: proc(object: ^Wavefront_Object_File, file: string, allocator := context.allocator) -> bool {
  bytes, ok := os.read_entire_file(name = file, allocator = context.temp_allocator);
  if !ok {
    log.errorf("Error reading the file: %s", file);
    return false;
  }
  object.file = file;
  defer free_all(context.temp_allocator);
  return wavefront_object_file_parser(object, bytes, allocator);
}

destroy_wavefront_object :: proc(object: Wavefront_Object) {
  if object.vertices != nil do delete(object.vertices);
  if object.texture_coords != nil do delete(object.texture_coords);
  if object.vertex_normals != nil do delete(object.vertex_normals);
  if object.faces != nil do delete(object.faces);
  if object.face_textures != nil do delete(object.face_textures);
  if object.face_normals != nil do delete(object.face_normals);
  if object.lines != nil do delete(object.lines);
}

destroy_wavefront_object_file :: proc(object: ^Wavefront_Object_File) {
  if object.file != "" do delete(object.file);
  for m in object.mtllibs {
    delete(m);
  }
  delete(object.mtllibs);
  for o in object.objects {
    destroy_wavefront_object(o);
  }
  delete(object.objects);
}
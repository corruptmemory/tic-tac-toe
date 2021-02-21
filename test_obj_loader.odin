package main

import lin "core:math/linalg"
import "core:log"
import fp "core:path/filepath"
import "core:mem"

Generic_Object :: struct {
  allocator: mem.Allocator,
  vertices: []lin.Vector4,
  texture_coords : []lin.Vector3,
  vertex_normals : []lin.Vector3,
  faces: []u32,
  face_textures: []u32,
  face_normals: []u32,
  lines: []u32,
  mtllib: string,
}


init_object :: proc(object: ^Generic_Object, allocator : mem.Allocator = context.allocator) {
  object.allocator = allocator;
}

obj_loader :: proc(file: string, object: ^Generic_Object) -> bool {

  return false;
}

destroy_object :: proc(object: ^Generic_Object) {
  context.allocator = object.allocator;
  if object.vertices != nil do delete(object.vertices);
  if object.texture_coords != nil do delete(object.texture_coords);
  if object.vertex_normals != nil do delete(object.vertex_normals);
  if object.faces != nil do delete(object.faces);
  if object.face_textures != nil do delete(object.face_textures);
  if object.face_normals != nil do delete(object.face_normals);
  if object.lines != nil do delete(object.lines);
  if object.mtllib != "" do delete(object.mtllib);
}
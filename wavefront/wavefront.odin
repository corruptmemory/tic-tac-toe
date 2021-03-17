package wavefront

import lin "core:math/linalg"

Wavefront_Object_File :: struct {
  file: string,
  mtllibs: [dynamic]string,
  objects: [dynamic]Wavefront_Object,
}

Wavefront_Object :: struct {
  vertices: [dynamic]lin.Vector4f32,
  texture_coords: [dynamic]lin.Vector3f32,
  vertex_normals: [dynamic]lin.Vector3f32,
  faces: [dynamic][dynamic]u32,
  face_textures: [dynamic][dynamic]u32,
  face_normals: [dynamic]u32,
  lines: [dynamic][dynamic]u32,
  usemtl: string,
  smooth_shading: bool,
  object: string,
}
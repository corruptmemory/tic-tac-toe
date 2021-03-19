package wavefront

import lin "core:math/linalg"
import "core:math/bits"

Wavefront_Object_File :: struct {
  file: string,
  mtllibs: [dynamic]string,
  objects: [dynamic]Wavefront_Object,
}

Face_Flag :: enum {
  Smooth_Shading,
}
Face_Flags :: bit_set[Face_Flag];

Face_Indices :: struct {
  vertices: []u32,
  texture_vertices: []u32,
  normals: []u32,
  flags: Face_Flags,
}

Wavefront_Object :: struct {
  vertices: [dynamic]lin.Vector4f32,
  texture_coords: [dynamic]lin.Vector3f32,
  vertex_normals: [dynamic]lin.Vector3f32,
  faces: [dynamic]Face_Indices,
  lines: [dynamic][dynamic]u32,
  usemtl: string,
  object: string,
}
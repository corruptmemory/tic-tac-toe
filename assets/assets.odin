package assets

import lin "core:math/linalg"

ThreeD_Model :: struct {
  vertices: [dynamic]lin.Vector4f32,
  texture_coords: [dynamic]lin.Vector3f32,
  vertex_normals: [dynamic]lin.Vector3f32,
  faces: [dynamic][dynamic]u32,
  face_textures: [dynamic][dynamic]u32,
  face_normals: [dynamic]u32,
  indices: []u32,
}

Asset_Catalog :: struct {
  models: map[string]ThreeD_Model,
}
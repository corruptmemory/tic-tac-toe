package assets

import lin "core:math/linalg"

Vertex :: struct {
  pos: lin.Vector3f32,
  color: lin.Vector3f32,
  texture_coord: lin.Vector2f32,
  vertex_normal: lin.Vector3f32,
};

ThreeD_Model :: struct {
  vertices: [dynamic]Vertex,
  faces: [dynamic][dynamic]u32,
  indices: []u32,
}

Asset_Catalog :: struct {
  models: map[string]ThreeD_Model,
}


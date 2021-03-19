package assets

import wf "../wavefront";
import "core:log"

load_3d_models :: proc(assets: ^Asset_Catalog, file: string, allocator := context.allocator) -> bool {
  wff: wf.Wavefront_Object_File;
  wf.init_wavefront_object_file(&wff);
  if !wf.wavefront_object_file_load_file(&wff, file, allocator) {
    log.errorf("ERROR: failed to load: %s", file);
    return false;
  }
  for obj in wff.objects {
    vertices := make([dynamic]Vertex, 0, len(obj.faces) * 3, allocator);
    indices := make([dynamic]u32, 0, len(obj.faces) * 3, allocator);
    unique_vertices := make(map[Vertex]u32, 16, allocator);

    for f, fidx in obj.faces {
      for i, iidx in f.vertices {
        v := obj.vertices[i];
        tv := obj.texture_coords[f.texture_vertices[iidx]];
        vn := obj.vertex_normals[f.normals[iidx]];
        vertex := Vertex{
          pos = { v[0], v[1], v[2] },
          color = { 1.0, 1.0, 1.0 },
          texture_coord = {tv[0], 1.0 - tv[1]},
          vertex_normal = vn,
        };

        if _, ok := unique_vertices[vertex]; !ok {
          unique_vertices[vertex] = u32(len(vertices));
          append(&vertices, vertex);
        }
        append(&indices, unique_vertices[vertex]);
      }
    }

    tdm := ThreeD_Model {
      vertices = vertices,
      // faces: [dynamic][dynamic]u32,
      indices = indices[:],
    };
    assets.models[obj.object] = tdm;
  }
  return true;
}
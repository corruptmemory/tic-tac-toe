package wavefront

import lin "core:math/linalg"
import "core:strings"
import bts "core:bytes"

@private VALID_STARTS :: "flomsuv";
@private TOP_LEVEL_STARTS :: "om";
@private BEVEL_KEYWORD :: "bevel";
@private BMAT_KEYWORD :: "bmat";
@private C_INTERP_KEYWORD :: "c_interp";
@private CALL_KEYWORD :: "call";
@private CON_KEYWORD :: "con";
@private CSH_KEYWORD :: "csh";
@private CSTYPE_KEYWORD :: "cstype";
@private CTECH_KEYWORD :: "ctech";
@private CURV_KEYWORD :: "curv";
@private CURV2_KEYWORD :: "curv2";
@private D_INTERP_KEYWORD :: "d_interp";
@private DEG_KEYWORD :: "deg";
@private END_KEYWORD :: "end";
@private F_KEYWORD :: "f";
@private G_KEYWORD :: "g";
@private HOLE_KEYWORD :: "hole";
@private L_KEYWORD :: "l";
@private LOD_KEYWORD :: "lod";
@private MG_KEYWORD :: "mg";
@private MTLLIB_KEYWORD :: "mtllib";
@private O_KEYWORD :: "o";
@private P_KEYWORD :: "p";
@private PARM_KEYWORD :: "parm";
@private S_KEYWORD :: "s";
@private SCRV_KEYWORD :: "scrv";
@private SHADOW_OBJ_KEYWORD :: "shadow_obj";
@private SP_KEYWORD :: "sp";
@private STECH_KEYWORD :: "stech";
@private STEP_KEYWORD :: "step";
@private SURF_KEYWORD :: "surf";
@private TRACE_OBJ_KEYWORD :: "trace_obj";
@private TRIM_KEYWORD :: "trim";
@private USEMTL_KEYWORD :: "usemtl";
@private V_KEYWORD :: "v";
@private VN_KEYWORD :: "vn";
@private VP_KEYWORD :: "vp";
@private VT_KEYWORD :: "vt";

wavefront_object_parser :: proc(scanner: ^Wavefront_Object_Scanner, allocator := context.allocator) -> (Wavefront_Object, bool) {
  object := Wavefront_Object{};
  vertices := make([dynamic]u32, context.temp_allocator);
  texture_coords := make([dynamic]u32,  context.temp_allocator);
  vertex_normals := make([dynamic]u32, context.temp_allocator);
  faces := make([dynamic]u32, context.temp_allocator);
  lines := make([dynamic]u32, context.temp_allocator);

  // We start out at the beginning of a line.  the value we find there determines what we do next
  use_found:
  for !wavefront_object_scanner_finished(scanner) {
    v := wavefront_object_scanner_byte_at_pos(scanner);
    // log.debugf("v: %v", rune(v));
    switch {
    case strings.index_byte(VALID_STARTS, v) > -1:
      switch v {
       case 'm':
      case 'o':
        if wavefront_object_scanner_keyword_check(scanner, O_KEYWORD) {
          break use_found;
        } else do wavefront_object_scanner_past_eol(scanner);
     case 'u':
        if wavefront_object_scanner_keyword_check(scanner, USEMTL_KEYWORD) {
          u := wavefront_object_scanner_consume_to_eol(scanner);
          if len(u) > 0 {
            object.usemtl = string(bts.clone(u, allocator));
          }
        } else do wavefront_object_scanner_past_eol(scanner);
      case 's':
        if wavefront_object_scanner_keyword_check(scanner, S_KEYWORD) {
          s := wavefront_object_scanner_consume_to_eol(scanner);
          if len(s) > 0 {
            switch string(s) {
            case "on", "ON", "1", "t", "T", "true", "TRUE", "True":
              object.smooth_shading = true;
            case: // We could check for an error.  Being lazy at the moment.
            }
          }
        } else do wavefront_object_scanner_past_eol(scanner);
      case 'v':
        switch {
          case wavefront_object_scanner_keyword_check(scanner, V_KEYWORD):
            append(&vertices,scanner.pos);
            wavefront_object_scanner_past_eol(scanner);
          case wavefront_object_scanner_keyword_check(scanner, VT_KEYWORD):
            append(&texture_coords,scanner.pos);
            wavefront_object_scanner_past_eol(scanner);
          case wavefront_object_scanner_keyword_check(scanner, VN_KEYWORD):
            append(&vertex_normals,scanner.pos);
            wavefront_object_scanner_past_eol(scanner);
          case: // Perhaps another time
            wavefront_object_scanner_past_eol(scanner);
        }
      case 'f':
        if wavefront_object_scanner_keyword_check(scanner, F_KEYWORD) {
          append(&faces,scanner.pos);
          wavefront_object_scanner_past_eol(scanner);
        } else do wavefront_object_scanner_past_eol(scanner);
      case 'l':
        if wavefront_object_scanner_keyword_check(scanner, L_KEYWORD) {
          append(&faces,scanner.pos);
          wavefront_object_scanner_past_eol(scanner);
        } else do wavefront_object_scanner_past_eol(scanner);
      }
    case:
      switch v {
        case '\r':
          scanner.pos += 1;
          fallthrough;
        case '\n':
          scanner.pos += 1;
          scanner.line += 1;
          wavefront_object_scanner_eos_fixup(scanner);
        case:
          wavefront_object_scanner_past_eol(scanner);
      }
    }
  }

  object.vertices = make([dynamic]lin.Vector4f32, 0, len(vertices), allocator);
  for p in vertices {
    scanner.pos = p;
    x, y, z, w: f32;
    xok, yok, zok, wok:bool;
    x, xok = wavefront_object_scanner_consume_f32(scanner);
    y, yok = wavefront_object_scanner_consume_f32(scanner);
    z, zok = wavefront_object_scanner_consume_f32(scanner);
    w, wok = wavefront_object_scanner_consume_f32(scanner);
    if xok && yok && zok {
      v := lin.Vector4f32{x, y, z, 1.0};
      if wok {
        v[3] = w;
      }
      append(&object.vertices,v);
    }
  }
  object.texture_coords = make([dynamic]lin.Vector3f32, 0, len(texture_coords), allocator);
  for p in texture_coords {
    scanner.pos = p;
    u, v, w: f32;
    uok, vok, wok:bool;
    u, uok = wavefront_object_scanner_consume_f32(scanner);
    v, vok = wavefront_object_scanner_consume_f32(scanner);
    w, wok = wavefront_object_scanner_consume_f32(scanner);
    if uok {
      tc := lin.Vector3f32{u, 0.0, 0.0};
      if vok {
        tc[1] = v;
      }
      if wok {
        tc[2] = w;
      }
      append(&object.texture_coords,tc);
    }
  }
  object.vertex_normals = make([dynamic]lin.Vector3f32, 0, len(vertex_normals), allocator);
  for p in vertex_normals {
    scanner.pos = p;
    x, y, z: f32;
    xok, yok, zok:bool;
    x, xok = wavefront_object_scanner_consume_f32(scanner);
    y, yok = wavefront_object_scanner_consume_f32(scanner);
    z, zok = wavefront_object_scanner_consume_f32(scanner);
    if xok && yok && zok {
      vn := lin.Vector3f32{x, y, z};
      append(&object.vertex_normals,vn);
    }
  }
  object.faces = make([dynamic][dynamic]u32, 0, len(faces), allocator);
  object.face_textures = make([dynamic][dynamic]u32, 0, len(faces), allocator);
  object.face_normals = make([dynamic]u32, 0, len(faces), allocator);
  for p in faces {
    scanner.pos = p;
    usedNormal := false;
    fis := make([dynamic]u32, allocator);
    ftis := make([dynamic]u32, allocator);
    fni: u32 = 0;
    for {
      fi, fiok := wavefront_object_scanner_consume_u32(scanner);
      if fiok {
        append(&fis, fi - scanner.vertex_base);
        if scanner.bytes[scanner.pos] == '/' {
          scanner.pos += 1;
          fti, ftiok := wavefront_object_scanner_consume_u32(scanner);
          if ftiok {
            append(&ftis, fti - scanner.texture_coords_base);
          }
        }
        if scanner.bytes[scanner.pos] == '/' {
          scanner.pos += 1;
          if !usedNormal {
            tfni, fniok := wavefront_object_scanner_consume_u32(scanner);
            if fniok {
              fni = tfni - scanner.vertex_normals_base;
              usedNormal = true;
            }
          } else {
            _, _ = wavefront_object_scanner_consume_u32(scanner);
          }
        }
        continue;
      }
      break;
    }
    if len(fis) > 0 do append(&object.faces, fis);
    if len(ftis) > 0 do append(&object.face_textures, ftis);
    if usedNormal do append(&object.face_normals, fni);
  }
  object.lines = make([dynamic][dynamic]u32, 0, len(lines), allocator);
  for p in lines {
    scanner.pos = p;
    lis := make([dynamic]u32, allocator);
    for {
      li, liok := wavefront_object_scanner_consume_u32(scanner);
      if liok {
        append(&lis, li - scanner.vertex_base);
        continue;
      }
      break;
    }
    if len(lis) > 0 do append(&object.lines, lis);
  }
  scanner.vertex_base += u32(len(vertices));
  scanner.texture_coords_base += u32(len(texture_coords));
  scanner.vertex_normals_base += u32(len(vertex_normals));

  return object, true;
}

wavefront_object_file_parser :: proc(object_file: ^Wavefront_Object_File, bytes: []byte, allocator := context.allocator) -> bool {
  scanner: Wavefront_Object_Scanner;
  wavefront_object_scanner_init(&scanner, bytes);

  object_name: string;

  // We start out at the beginning of a line.  the value we find there determines what we do next
  for !wavefront_object_scanner_finished(&scanner) {
    v := wavefront_object_scanner_byte_at_pos(&scanner);
    // log.debugf("v: %v - pos: %d", rune(v), scanner.pos);
    switch {
    case strings.index_byte(TOP_LEVEL_STARTS, v) > -1:
      switch v {
       case 'm':
        if wavefront_object_scanner_keyword_check(&scanner, MTLLIB_KEYWORD) {
          m := wavefront_object_scanner_consume_to_eol(&scanner);
          if len(m) > 0 {
            append(&object_file.mtllibs, string(bts.clone(m, allocator)));
          }
        } else {
          wavefront_object_scanner_past_eol(&scanner);
        }
      case 'o':
        if wavefront_object_scanner_keyword_check(&scanner, O_KEYWORD) {
          o := wavefront_object_scanner_consume_to_eol(&scanner);
          if len(o) > 0 {
            object_name = string(bts.clone(o, allocator));
            obj, ok := wavefront_object_parser(&scanner,allocator);
            if ok {
              obj.object = object_name;
              append(&object_file.objects,obj);
            }
          }
        } else do wavefront_object_scanner_past_eol(&scanner);
      }
    case:
      switch v {
        case '\r':
          scanner.pos += 1;
          fallthrough;
        case '\n':
          scanner.pos += 1;
          scanner.line += 1;
          wavefront_object_scanner_eos_fixup(&scanner);
        case:
          wavefront_object_scanner_past_eol(&scanner);
      }
    }
  }

  return true;
}

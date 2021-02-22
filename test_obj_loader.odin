package main

import lin "core:math/linalg"
import "core:log"
import fp "core:path/filepath"
import "core:mem"
import "core:os"
import "core:strings"
import bts "core:bytes"
import "core:fmt"
import "core:strconv"

Generic_Object :: struct {
  vertices: [dynamic]lin.Vector4,
  texture_coords: [dynamic]lin.Vector3,
  vertex_normals: [dynamic]lin.Vector3,
  faces: [dynamic][dynamic]u32,
  face_textures: [dynamic][dynamic]u32,
  face_normals: [dynamic]u32,
  lines: [dynamic][dynamic]u32,
  mtllib: string,
  usemtl: string,
  smooth_shading: bool,
  object: string,
}

@private VALID_STARTS :: "flomsuv";
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

@private
Waveform_Object_Scanner :: struct {
  eos: u32,
  bytes: []byte,
  pos: u32,
  line: u32,
}

@private
wos_init :: proc(scanner: ^Waveform_Object_Scanner, bytes: []byte) {
  scanner.bytes = bytes;
  scanner.eos = u32(len(bytes));
}

@private
wos_finished :: inline proc(scanner: ^Waveform_Object_Scanner) -> bool {
  return scanner.pos == scanner.eos;
}

@private
eos_fixup :: inline proc(scanner: ^Waveform_Object_Scanner) {
  if scanner.pos > scanner.eos do scanner.pos = scanner.eos;
}


@private
past_eol :: proc(scanner: ^Waveform_Object_Scanner) {
  eos := scanner.eos;
  for pos := scanner.pos; pos < eos; pos += 1 {
    v := scanner.bytes[pos];
    switch v {
      case '\r':
        pos += 1;
        fallthrough;
      case '\n':
        pos += 1;
        scanner.line += 1;
        scanner.pos = pos;
        eos_fixup(scanner);
        return;
      case: // nothing
        continue;
    }
  }
  scanner.pos = eos;
  return;
}


/* consume_to_eol will return the bytes from the current position to the end of line
 * _excluding_ comments.  Which are completely ignored.
 */
@private
consume_to_eol :: proc(scanner: ^Waveform_Object_Scanner) -> []byte {
  eos := scanner.eos;
  start, end: u32 = scanner.pos, scanner.pos;
  for pos := scanner.pos; pos < eos; pos += 1 {
    v := scanner.bytes[pos];
    switch v {
      case '\r':
        end = pos;
        pos += 1;
        fallthrough;
      case '\n':
        // This is here because of the fallthrough case.  This is triggered
        // only for Unix-style line endings.  Otherwise we have Windows-style line
        // endings.
        if v == '\n' {
          end = pos;
        }
        pos += 1;
        scanner.line += 1;
        scanner.pos = pos;
        eos_fixup(scanner);
        return scanner.bytes[start:end];
      case '#':
        if pos == start {
          for ; pos < eos; pos += 1 {
            v := scanner.bytes[pos];
            switch v {
              case '\r':
                pos += 1;
                fallthrough;
              case '\n':
                pos += 1;
                scanner.line += 1;
                scanner.pos = pos;
                eos_fixup(scanner);
                return scanner.bytes[pos:pos];
            }
          }
          scanner.pos = eos;
          return scanner.bytes[eos-1:eos-1];
        } else {
          // Since we have started a comment, we will need to record as the "end"
          // the last word character.  We will then do our best to move to the end of line
          for i : u32 = pos; i > 0; i -= 1 {
            v := scanner.bytes[pos];
            if v != ' ' && v != '\t' {
              end = i;
              break;
            }
          }
          for ; pos < eos; pos += 1 {
            v := scanner.bytes[pos];
            switch v {
              case '\r':
                pos += 1;
                fallthrough;
              case '\n':
                pos += 1;
                scanner.line += 1;
                scanner.pos = pos;
                eos_fixup(scanner);
                return scanner.bytes[start:end];
            }
          }
          scanner.pos = eos;
          return scanner.bytes[start:pos-1];
        }
      case:
        continue;
    }
  }
  scanner.pos = eos;
  return scanner.bytes[start:eos-1];
}

@private
consume_number :: proc(scanner: ^Waveform_Object_Scanner) -> []byte {
  eos := scanner.eos;
  start, end: u32 = scanner.pos, scanner.pos;
  stop:
  for pos := scanner.pos; pos < eos; pos += 1 {
    switch scanner.bytes[pos] {
    case '0'..'9', '+', '-', '.', 'E', 'e':
      continue;
    case:
      end = pos;
      scanner.pos = pos;
      eos_fixup(scanner);
      break stop;
    }
  }
  past_whitespace(scanner);
  return scanner.bytes[start:end];
}

@private
consume_f32 :: proc(scanner: ^Waveform_Object_Scanner) -> (f32, bool) {
  bs := consume_number(scanner);
  if len(bs) > 0 {
    return strconv.parse_f32(string(bs));
  }
  return 0.0, false;
}

@private
consume_u32 :: proc(scanner: ^Waveform_Object_Scanner) -> (u32, bool) {
  bs := consume_number(scanner);
  if len(bs) > 0 {
    r, ok := strconv.parse_u64(string(bs));
    return u32(r), ok;
  }
  return 0, false;
}

@private
past_whitespace :: proc(scanner: ^Waveform_Object_Scanner) {
  eos := scanner.eos;
  for pos := scanner.pos; pos < eos; pos += 1 {
    v := scanner.bytes[pos];
    switch v {
      case ' ', '\t':
        continue;
      case:
        scanner.pos = pos;
        return;
    }
  }
  scanner.pos = eos;
  return;
}

@private
keyword_check :: inline proc(scanner: ^Waveform_Object_Scanner, keyword: string) -> bool {
  here := string(scanner.bytes[scanner.pos:]);
  if strings.has_prefix(here, keyword) {
    kl := u32(len(keyword));
    pos := kl + scanner.pos;
    if pos < scanner.eos {
      switch scanner.bytes[pos] {
        case ' ', '\t':
          scanner.pos = pos;
          past_whitespace(scanner);
          return true;
        case:
          return false;
      }
    }
  }
  return false;
}


obj_parser :: proc(object: ^Generic_Object, bytes: []byte, allocator := context.allocator) -> bool {
  scanner: Waveform_Object_Scanner;
  wos_init(&scanner, bytes);

  vertices := make([dynamic]u32, context.temp_allocator);
  texture_coords := make([dynamic]u32,  context.temp_allocator);
  vertex_normals := make([dynamic]u32, context.temp_allocator);
  faces := make([dynamic]u32, context.temp_allocator);
  lines := make([dynamic]u32, context.temp_allocator);

  // We start out at the beginning of a line.  the value we find there determines what we do next
  for scanner.pos < scanner.eos {
    v := scanner.bytes[scanner.pos];
    switch {
    case strings.index_byte(VALID_STARTS, v) > -1:
      switch v {
       case 'm':
        if keyword_check(&scanner, MTLLIB_KEYWORD) {
          m := consume_to_eol(&scanner);
          if len(m) > 0 {
            object.mtllib = string(bts.clone(m, allocator));
          }
        } else {
          past_eol(&scanner);
        }
      case 'o':
        if keyword_check(&scanner, O_KEYWORD) {
          o := consume_to_eol(&scanner);
          if len(o) > 0 {
            object.object = string(bts.clone(o, allocator));
          }
        } else do past_eol(&scanner);
     case 'u':
        if keyword_check(&scanner, USEMTL_KEYWORD) {
          u := consume_to_eol(&scanner);
          if len(u) > 0 {
            object.usemtl = string(bts.clone(u, allocator));
          }
        } else do past_eol(&scanner);
      case 's':
        if keyword_check(&scanner, S_KEYWORD) {
          s := consume_to_eol(&scanner);
          if len(s) > 0 {
            switch string(s) {
            case "on", "ON", "1", "t", "T", "true", "TRUE", "True":
              object.smooth_shading = true;
            case: // We could check for an error.  Being lazy at the moment.
            }
          }
        } else do past_eol(&scanner);
      case 'v':
        switch {
          case keyword_check(&scanner, V_KEYWORD):
            append(&vertices,scanner.pos);
            past_eol(&scanner);
          case keyword_check(&scanner, VT_KEYWORD):
            append(&texture_coords,scanner.pos);
            past_eol(&scanner);
          case keyword_check(&scanner, VN_KEYWORD):
            append(&vertex_normals,scanner.pos);
            past_eol(&scanner);
          case: // Perhaps another time
            past_eol(&scanner);
        }
      case 'f':
        if keyword_check(&scanner, F_KEYWORD) {
          append(&faces,scanner.pos);
          past_eol(&scanner);
        } else do past_eol(&scanner);
      case 'l':
        if keyword_check(&scanner, L_KEYWORD) {
          append(&faces,scanner.pos);
          past_eol(&scanner);
        } else do past_eol(&scanner);
      }
    case:
      switch v {
        case '\r':
          scanner.pos += 1;
          fallthrough;
        case '\n':
          scanner.pos += 1;
          scanner.line += 1;
          eos_fixup(&scanner);
        case:
          past_eol(&scanner);
      }
    }
  }

  object.vertices = make([dynamic]lin.Vector4, 0, len(vertices), allocator);
  for p in vertices {
    scanner.pos = p;
    x, y, z, w: f32;
    xok, yok, zok, wok:bool;
    x, xok = consume_f32(&scanner);
    y, yok = consume_f32(&scanner);
    z, zok = consume_f32(&scanner);
    w, wok = consume_f32(&scanner);
    if xok && yok && zok {
      v := lin.Vector4{x, y, z, 1.0};
      if wok {
        v[3] = w;
      }
      append(&object.vertices,v);
    }
  }
  object.texture_coords = make([dynamic]lin.Vector3, 0, len(texture_coords), allocator);
  for p in texture_coords {
    scanner.pos = p;
    u, v, w: f32;
    uok, vok, wok:bool;
    u, uok = consume_f32(&scanner);
    v, vok = consume_f32(&scanner);
    w, wok = consume_f32(&scanner);
    if uok {
      tc := lin.Vector3{u, 0.0, 0.0};
      if vok {
        tc[1] = v;
      }
      if wok {
        tc[2] = w;
      }
      append(&object.texture_coords,tc);
    }
  }
  object.vertex_normals = make([dynamic]lin.Vector3, 0, len(vertex_normals), allocator);
  for p in vertex_normals {
    scanner.pos = p;
    x, y, z: f32;
    xok, yok, zok:bool;
    x, xok = consume_f32(&scanner);
    y, yok = consume_f32(&scanner);
    z, zok = consume_f32(&scanner);
    if xok && yok && zok {
      vn := lin.Vector3{x, y, z};
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
      fi, fiok := consume_u32(&scanner);
      if fiok {
        append(&fis, fi - 1);
        if scanner.bytes[scanner.pos] == '/' {
          scanner.pos += 1;
          fti, ftiok := consume_u32(&scanner);
          if ftiok {
            append(&ftis, fti - 1);
          }
        }
        if scanner.bytes[scanner.pos] == '/' {
          scanner.pos += 1;
          if !usedNormal {
            tfni, fniok := consume_u32(&scanner);
            if fniok {
              fni = tfni - 1;
              usedNormal = true;
            }
          } else {
            _, _ = consume_u32(&scanner);
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
      li, liok := consume_u32(&scanner);
      if liok {
        append(&lis, li - 1);
        continue;
      }
      break;
    }
    if len(lis) > 0 do append(&object.lines, lis);
  }

  return true;
}


init_object :: proc(object: ^Generic_Object) {
}

obj_loader :: proc(file: string, object: ^Generic_Object, allocator := context.allocator) -> bool {
  bytes, ok := os.read_entire_file(name = file, allocator = context.temp_allocator);
  if !ok {
    log.errorf("Error reading the file: %s", file);
    return false;
  }
  defer free_all(context.temp_allocator);
  return obj_parser(object, bytes, allocator);
}

destroy_object :: proc(object: ^Generic_Object) {
  if object.vertices != nil do delete(object.vertices);
  if object.texture_coords != nil do delete(object.texture_coords);
  if object.vertex_normals != nil do delete(object.vertex_normals);
  if object.faces != nil do delete(object.faces);
  if object.face_textures != nil do delete(object.face_textures);
  if object.face_normals != nil do delete(object.face_normals);
  if object.lines != nil do delete(object.lines);
  if object.mtllib != "" do delete(object.mtllib);
}

main :: proc() {
  context.logger = log.create_console_logger(lowest = log.Level.Debug);
  go: Generic_Object;
  init_object(&go);
  ok := obj_loader("/home/jim/projects/tic-tac-toe/blender/donut.obj", &go);
  fmt.printf("go: %v\n", go);
}
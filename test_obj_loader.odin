package main

import lin "core:math/linalg"
import "core:log"
import fp "core:path/filepath"
import "core:mem"
import "core:os"
import "core:strings"
import bts "core:bytes"
import "core:fmt"

Generic_Object :: struct {
  vertices: []lin.Vector4,
  texture_coords : []lin.Vector3,
  vertex_normals : []lin.Vector3,
  faces: []u32,
  face_textures: []u32,
  face_normals: []u32,
  lines: []u32,
  mtllib: string,
  usemtl: string,
  smooth_shading: bool,
  object: string,
}

@private VALID_STARTS :: "flosuv";
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
past_eol :: proc(bytes: []byte) -> u32 {
  eos := u32(len(bytes));
  for pos : u32 = 0; pos < eos; pos += 1 {
    v := bytes[pos];
    switch v {
      case '\r':
        pos += 1;
        fallthrough;
      case '\n':
        pos += 1;
        return pos;
      case: // nothing
    }
  }
  return eos;
}

@private
consume_to_eol :: proc(bytes: []byte) -> ([]byte, u32) {
  eos := u32(len(bytes));
  end : u32 = 0;
  for pos : u32 = 0; pos < eos; pos += 1 {
    v := bytes[pos];
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
        return bytes[0:end], pos;
      case '#':
        if pos == 0 {
          for ; pos < eos; pos += 1 {
            v := bytes[pos];
            switch v {
              case '\r':
                pos += 1;
                fallthrough;
              case '\n':
                pos += 1;
                return bytes[0:0], pos;
            }
          }
          return bytes[0:0], eos;
        } else {
          // Since we have started a comment, we will need to record as the "end"
          // the last word character.  We will then do our best to move to the end of line
          for i : u32 = pos; i > 0; i -= 1 {
            v := bytes[pos];
            if v != ' ' && v != '\t' {
              end = i;
              break;
            }
          }
          for ; pos < eos; pos += 1 {
            v := bytes[pos];
            switch v {
              case '\r':
                pos += 1;
                fallthrough;
              case '\n':
                pos += 1;
                return bytes[0:end], pos;
            }
          }
          return bytes[0:end], eos;
        }
      case:
        continue;
    }
  }
  return bytes[0:eos], eos;
}


@private
past_whitespace :: proc(bytes: []byte) -> u32 {
  eos := u32(len(bytes));
  for pos : u32 = 0; pos < eos; pos += 1 {
    v := bytes[pos];
    switch v {
      case ' ':
      case '\t':
      case:
        return pos;
    }
  }
  return eos;
}


obj_parser :: proc(object: ^Generic_Object, bytes: []byte, allocator := context.allocator) -> bool {

  defer free_all(context.temp_allocator);

  vertices: []u32;
  texture_coords: []u32;
  vertex_normals: []u32;
  faces: []u32;
  face_textures: []u32;
  face_normals: []u32;
  lines: []u32;


  line := 0;
  eos := u32(len(bytes));
  // We start out at the beginning of a line.  the value we find there determines what we do next
  for pos : u32 = 0; pos < eos; pos += 1 {
    v := bytes[pos];
    switch {
    case strings.index_byte(VALID_STARTS, v) > -1 :
      switch v {
      case 'o':
        pos += past_whitespace(bytes[pos:]);
        if pos < eos {
          o, p := consume_to_eol(bytes[pos:]);
          if len(o) > 0 {
            object.object = string(bts.clone(o, allocator));
          }
          pos += p;
        }
      case 'm':
        if pos < eos {

        }
      case 'u':
      case 's':

      }
    case:
      switch v {
        case '\r':
          pos += 1;
          fallthrough;
        case '\n':
          pos += 1;
          line += 1;
        case:
          pos += past_eol(bytes[pos:]);
          line += 1;
      }
    }
  }

  return true;
}


init_object :: proc(object: ^Generic_Object) {
}

obj_loader :: proc(file: string, object: ^Generic_Object) -> bool {
  bytes, ok := os.read_entire_file(name = file, allocator = context.temp_allocator);
  if !ok {
    log.errorf("Error reading the file: %s", file);
    return false;
  }
  defer free_all(context.temp_allocator);

  return false;
}

destroy_object :: proc(object: ^Generic_Object, allocator := context.allocator) {
  if object.vertices != nil do delete(object.vertices, allocator);
  if object.texture_coords != nil do delete(object.texture_coords, allocator);
  if object.vertex_normals != nil do delete(object.vertex_normals, allocator);
  if object.faces != nil do delete(object.faces, allocator);
  if object.face_textures != nil do delete(object.face_textures, allocator);
  if object.face_normals != nil do delete(object.face_normals, allocator);
  if object.lines != nil do delete(object.lines, allocator);
  if object.mtllib != "" do delete(object.mtllib, allocator);
}

main :: proc() {
  x := []byte{};
  p := past_whitespace(x);
  fmt.printf("p: %d\n",p);
}
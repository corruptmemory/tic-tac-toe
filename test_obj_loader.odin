package main

import lin "core:math/linalg"
import "core:log"
import fp "core:path/filepath"
import "core:mem"
import "core:os"
import "core:strings"
import "core:fmt"

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


Scanner :: struct {
  str: string,
  line: u32,
  pos: u32,
}

init_scanner :: proc(scanner: ^Scanner, init: string) {
  scanner.str = init;
}

scan_to_eol :: proc(scanner: ^Scanner) -> bool {
  if scanner.pos == u32(len(scanner.str)) do return true;
  idx := strings.index_rune(scanner.str[scanner.pos:], '\n');
  if idx == -1 do return true;
  scanner.line += 1;
  scanner.pos += u32(idx + 1);
  return false;
}

scan_past_token :: proc(scanner: ^Scanner, token: string) -> bool {
  if scanner.pos == u32(len(scanner.str)) do return true;
  idx := strings.index(scanner.str[scanner.pos:], token);
  if idx == -1 {
    scanner.pos = u32(len(scanner.str));
    return true;
  }
  scanner.pos += u32(idx + len(token));
  return false;
}

@private WORD_CHARS :: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ#0123456789";

scan_word :: proc(scanner: ^Scanner, chars: string) -> (string, bool) {
  if scanner.pos == u32(len(scanner.str)) do return "", true;
  start := scanner.pos;
  cur: u32;
  for cur = scanner.pos; (cur < u32(len(scanner.str))) && strings.index_byte(chars, scanner.str[cur]) > -1; cur += 1 {}
  scanner.pos = cur;
  if cur == u32(len(scanner.str)) do return scanner.str[start:cur], true;
  return scanner.str[start:cur], false;
}


init_object :: proc(object: ^Generic_Object, allocator : mem.Allocator = context.allocator) {
  object.allocator = allocator;
}

obj_loader :: proc(file: string, object: ^Generic_Object) -> bool {
  bytes, ok := os.read_entire_file(name = file, allocator = context.temp_allocator);
  if !ok {
    log.errorf("Error reading the file: %s", file);
    return false;
  }
  defer delete(bytes, context.temp_allocator);

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

main :: proc() {
  // 138846618033284628480.000
  f : f64 = 1e+37;
  x := `hello, world!
As you can see there is more`;
  scn: Scanner;
  init_scanner(&scn, x);
  wrd, eof := scan_word(&scn, WORD_CHARS);
  fmt.printf("wrd: %s -- eof: %v - pos: %d\n", wrd, eof, scn.pos);
  eof = scan_past_token(&scn, ", ");
  fmt.printf("eof: %v - pos: %d\n", eof, scn.pos);
  wrd, eof = scan_word(&scn, WORD_CHARS);
  fmt.printf("wrd: %s -- eof: %v - pos: %d\n", wrd, eof, scn.pos);
  eof = scan_to_eol(&scn);
  fmt.printf("eof: %v - pos: %d\n", eof, scn.pos);
  for wrd, eof = scan_word(&scn, WORD_CHARS); !eof; wrd, eof = scan_word(&scn, WORD_CHARS) {
    fmt.printf("wrd: %s -- eof: %v - pos: %d\n", wrd, eof, scn.pos);
    eof = scan_past_token(&scn, " ");
    fmt.printf("eof: %v - pos: %d\n", eof, scn.pos);
  }
  fmt.printf("wrd: %s -- eof: %v - pos: %d\n", wrd, eof, scn.pos);
  fmt.printf("big: %e\n", f);
}
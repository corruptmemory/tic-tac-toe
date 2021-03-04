package wavefront

import "core:strings"
import "core:strconv"

@private
Wavefront_Object_Scanner :: struct {
  eos: u32,
  bytes: []byte,
  pos: u32,
  line: u32,
  vertex_base: u32,
  texture_coords_base: u32,
  vertex_normals_base: u32,
}

@private
wavefront_object_scanner_advance_pos :: #force_inline proc(scanner: ^Wavefront_Object_Scanner, amount: u32 = 1) -> bool {
  if !wavefront_object_scanner_finished(scanner) {
    scanner.pos += amount;
    wavefront_object_scanner_eos_fixup(scanner);
    return !wavefront_object_scanner_finished(scanner);
  }
  return false;
}

@private
wavefront_object_scanner_advance_line :: #force_inline proc(scanner: ^Wavefront_Object_Scanner, amount: u32 = 1) {
  scanner.line += amount;
}


@private
wavefront_object_scanner_set_vertex_base_index :: #force_inline proc(scanner: ^Wavefront_Object_Scanner, point: u32) {
  scanner.vertex_base = point;
}

@private
wavefront_object_scanner_set_texture_coords_base_index :: #force_inline proc(scanner: ^Wavefront_Object_Scanner, point: u32) {
  scanner.texture_coords_base = point;
}

@private
wavefront_object_scanner_set_vertex_normals_base_index :: #force_inline proc(scanner: ^Wavefront_Object_Scanner, point: u32) {
  scanner.vertex_normals_base = point;
}

@private
wavefront_object_scanner_byte_at_pos :: #force_inline proc(scanner: ^Wavefront_Object_Scanner) -> byte {
  return scanner.bytes[scanner.pos];
}

@private
wavefront_object_scanner_init :: proc(scanner: ^Wavefront_Object_Scanner, bytes: []byte) {
  scanner.bytes = bytes;
  scanner.eos = u32(len(bytes));
  scanner.vertex_base=1;
  scanner.texture_coords_base=1;
  scanner.vertex_normals_base=1;
}

@private
wavefront_object_scanner_finished :: #force_inline proc(scanner: ^Wavefront_Object_Scanner) -> bool {
  return scanner.pos == scanner.eos;
}

@private
wavefront_object_scanner_eos_fixup :: #force_inline proc(scanner: ^Wavefront_Object_Scanner) {
  if scanner.pos > scanner.eos do scanner.pos = scanner.eos;
}


@private
wavefront_object_scanner_past_eol :: proc(scanner: ^Wavefront_Object_Scanner) -> bool {
  for !wavefront_object_scanner_finished(scanner) {
    v := wavefront_object_scanner_byte_at_pos(scanner);
    switch v {
      case '\r':
        if !wavefront_object_scanner_advance_pos(scanner) do return false;
        fallthrough;
      case '\n':
        if !wavefront_object_scanner_advance_pos(scanner) do return false;
        wavefront_object_scanner_advance_line(scanner);
        return true;
      case: // nothing
        if !wavefront_object_scanner_advance_pos(scanner) do return false;
        continue;
    }
  }
  return false;
}


/* wavefront_object_scanner_consume_to_eol will return the bytes from the current position to the end of line
 * _excluding_ comments.  Which are completely ignored.
 */
@private
wavefront_object_scanner_consume_to_eol :: proc(scanner: ^Wavefront_Object_Scanner) -> []byte {
  start, end: u32 = scanner.pos, scanner.pos;
  for !wavefront_object_scanner_finished(scanner) {
    v := wavefront_object_scanner_byte_at_pos(scanner);
    switch v {
      case '\r':
        end = scanner.pos;
        if !wavefront_object_scanner_advance_pos(scanner) do return scanner.bytes[start:end];
        fallthrough;
      case '\n':
        // This is here because of the fallthrough case.  This is triggered
        // only for Unix-style line endings.  Otherwise we have Windows-style line
        // endings.
        if v == '\n' {
          end = scanner.pos;
        }
        if !wavefront_object_scanner_advance_pos(scanner) do return scanner.bytes[start:end];
        wavefront_object_scanner_advance_line(scanner);
        return scanner.bytes[start:end];
      case '#':
        if scanner.pos == start {
          for !wavefront_object_scanner_finished(scanner) {
            v = wavefront_object_scanner_byte_at_pos(scanner);
            switch v {
              case '\r':
                if !wavefront_object_scanner_advance_pos(scanner) do return scanner.bytes[start:end];
                fallthrough;
              case '\n':
                if !wavefront_object_scanner_advance_pos(scanner) do return scanner.bytes[start:end];
                wavefront_object_scanner_advance_line(scanner);
                return scanner.bytes[start:end];
            }
            if !wavefront_object_scanner_advance_pos(scanner) do return scanner.bytes[start:end];
          }
          return scanner.bytes[scanner.eos-1:scanner.eos];
        } else {
          // Since we have started a comment, we will need to record as the "end"
          // the last word character.  We will then do our best to move to the end of line
          for i : u32 = scanner.pos; i > 0; i -= 1 {
            v = scanner.bytes[i];
            if v != ' ' && v != '\t' {
              end = i;
              break;
            }
          }
          for !wavefront_object_scanner_finished(scanner) {
            v = wavefront_object_scanner_byte_at_pos(scanner);
            switch v {
              case '\r':
                if !wavefront_object_scanner_advance_pos(scanner) do return scanner.bytes[start:end];
                fallthrough;
              case '\n':
                if !wavefront_object_scanner_advance_pos(scanner) do return scanner.bytes[start:end];
                wavefront_object_scanner_advance_line(scanner);
                return scanner.bytes[start:end];
            }
            if !wavefront_object_scanner_advance_pos(scanner) do return scanner.bytes[start:end];
          }
          return scanner.bytes[start:scanner.eos];
        }
      case:
        if !wavefront_object_scanner_advance_pos(scanner) do return scanner.bytes[start:end];
        continue;
    }
  }
  return scanner.bytes[start:scanner.eos];
}

@private
wavefront_object_scanner_consume_number :: proc(scanner: ^Wavefront_Object_Scanner) -> []byte {
  start, end: u32 = scanner.pos, scanner.pos;
  stop:
  for !wavefront_object_scanner_finished(scanner) {
    switch wavefront_object_scanner_byte_at_pos(scanner) {
    case '0'..'9', '+', '-', '.', 'E', 'e':
      end = scanner.pos;
      if !wavefront_object_scanner_advance_pos(scanner) do return scanner.bytes[start:end];
      continue;
    case:
      end = scanner.pos;
      break stop;
    }
  }
  wavefront_object_scanner_past_whitespace(scanner);
  return scanner.bytes[start:end];
}

@private
wavefront_object_scanner_consume_f32 :: proc(scanner: ^Wavefront_Object_Scanner) -> (f32, bool) {
  bs := wavefront_object_scanner_consume_number(scanner);
  if len(bs) > 0 {
    return strconv.parse_f32(string(bs));
  }
  return 0.0, false;
}

@private
wavefront_object_scanner_consume_u32 :: proc(scanner: ^Wavefront_Object_Scanner) -> (u32, bool) {
  bs := wavefront_object_scanner_consume_number(scanner);
  if len(bs) > 0 {
    r, ok := strconv.parse_u64(string(bs));
    return u32(r), ok;
  }
  return 0, false;
}

@private
wavefront_object_scanner_past_whitespace :: proc(scanner: ^Wavefront_Object_Scanner) {
  for !wavefront_object_scanner_finished(scanner) {
    switch wavefront_object_scanner_byte_at_pos(scanner) {
      case ' ', '\t':
        if !wavefront_object_scanner_advance_pos(scanner) do return;
        continue;
      case:
        return;
    }
  }
  return;
}

@private
wavefront_object_scanner_keyword_check :: #force_inline proc(scanner: ^Wavefront_Object_Scanner, keyword: string) -> bool {
  here := string(scanner.bytes[scanner.pos:]);
  if strings.has_prefix(here, keyword) {
    kl := u32(len(keyword));
    pos := kl + scanner.pos;
    if pos < scanner.eos {
      switch scanner.bytes[pos] {
        case ' ', '\t':
          scanner.pos = pos;
          wavefront_object_scanner_past_whitespace(scanner);
          return true;
        case:
          return false;
      }
    }
  }
  return false;
}

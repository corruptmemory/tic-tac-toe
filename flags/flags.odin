package flags

// import "core:os"
import "core:reflect"
import "core:mem"
import "core:fmt"
import "core:strings"
import "core:unicode/utf8"

ArgEntry :: struct {
  type: typeid,
  short: rune,
  long: string,
  description: string,
  hasDefault: bool,
  default: any,
  offset: uintptr,
}

Parser :: struct {
  type: typeid,
  allocator: mem.Allocator,
  args: []ArgEntry,
  shorts: map[rune]^ArgEntry,
  longs: map[string]^ArgEntry,
  commands: map[string]Parser,
};

new_parser :: proc($T: typeid) -> (Parser, bool) {
  arena := new(mem.Arena);
  mem.init_arena(arena,make([]byte,2048));
  allocator := mem.arena_allocator(arena);
  context.allocator = allocator;
  parser := Parser {
    type = T,
    allocator = allocator,
  };

  names := reflect.struct_field_names(T);
  types := reflect.struct_field_types(T);
  tags  := reflect.struct_field_tags(T);
  offsets := reflect.struct_field_offsets(T);

  args := make([dynamic]ArgEntry, len(names));

  for name, i in names {
    type := types[i];
    tag  := tags[i];
    offset := offsets[i];
    fmt.printf("processing field %s\n", name);
    if tag != "" {
      entry := ArgEntry{
        offset = offset,
      };
      if short, ok := reflect.struct_tag_lookup(tag,"short"); ok {
        assert(strings.rune_count(transmute(string)short) == 1);
        entry.short, _ = utf8.decode_rune_in_string(transmute(string)short);
      }
      if long, ok := reflect.struct_tag_lookup(tag,"long"); ok {
        entry.long = string(long);
      }
      if description, ok := reflect.struct_tag_lookup(tag,"long"); ok {
        entry.description = string(description);
      }
      append(&args, entry);
      switch type.id {
        case string:
          entry.type = string;
        case bool:
          entry.type = bool;
        case int:
          entry.type = int;
        case uint:
          entry.type = uint;
        case i32:
          entry.type = i32;
        case u32:
          entry.type = u32;
        case i64:
          entry.type = i64;
        case u64:
          entry.type = u64;
        case rune:
          entry.type = rune;
        case f32:
          entry.type = f32;
        case f64:
          entry.type = f64;
        case: // what to do here
      }
    }

  }

  return parser, true;
}

delete_parser :: proc(parser: ^Parser, allocator := context.allocator, loc := #caller_location) {
  free_all(parser.allocator);
  arena := cast(^mem.Arena)parser.allocator.data;
  delete(arena.data, allocator, loc);
  free((rawptr)(arena), allocator, loc);
}
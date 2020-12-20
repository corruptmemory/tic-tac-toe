package flags

import "core:reflect"
import "core:mem"
import "core:fmt"
import "core:strings"
import "core:strconv"
import "core:unicode/utf8"
import "core:math/bits"
import "core:log"

None :: distinct bool;

none :: None(false);

ArgEntry :: struct {
  type: typeid,
  short: rune,
  long: string,
  description: string,
  hasDefault: bool,
  required: bool,
  offset: uintptr,
  default: union {
    None,
    string,
    bool,
    int,
    uint,
    i32,
    u32,
    i64,
    u64,
    rune,
    f32,
    f64,
  },
}

ArgParser :: struct(T: typeid) {
  application: string,
  description: string,
  allocator: mem.Allocator,
  rootParser: ^Parser,
}

Parser :: struct {
  type: typeid,
  args: []ArgEntry,
  shorts: map[rune]int,
  longs: map[string]int,
};

process_struct :: proc(T: typeid) -> (^Parser, bool) {
  parser := new(Parser);
  parser.type = T;
  parser.shorts = make(map[rune]int);
  parser.longs = make(map[string]int);

  names := reflect.struct_field_names(T);
  types := reflect.struct_field_types(T);
  tags  := reflect.struct_field_tags(T);
  offsets := reflect.struct_field_offsets(T);

  args := make([dynamic]ArgEntry, 0, len(names));

  for name, i in names {
    type := types[i];
    tag  := tags[i];
    offset := offsets[i];
    if tag != "" {
      default:string;
      entry := ArgEntry{
        offset = offset,
        default = none,
      };
      if short, ok := reflect.struct_tag_lookup(tag,"short"); ok {
        assert(strings.rune_count(transmute(string)short) == 1);
        entry.short, _ = utf8.decode_rune_in_string(transmute(string)short);
      }
      if long, ok := reflect.struct_tag_lookup(tag,"long"); ok {
        entry.long = string(long);
      }
      if description, ok := reflect.struct_tag_lookup(tag,"description"); ok {
        entry.description = string(description);
      }
      if required, ok := reflect.struct_tag_lookup(tag,"required"); ok {
        if r, iok := strconv.parse_bool(string(required)); iok {
          entry.required = r;
        } else {
          log.errorf("error: 'required' field tag for '%s' has invalid value: %s", name, required);
          return nil, false;
        }
      }
      if def, ok := reflect.struct_tag_lookup(tag,"default"); ok {
        default = string(def);
      }

      switch type.id {
        case string:
          entry.type = string;
          if default != "" {
            entry.default = default;
          }
        case bool:
          entry.type = bool;
          if default != "" {
            if v, ok := strconv.parse_bool(default); ok {
              entry.default = v;
            } else {
              log.errorf("error: 'default' field tag for '%s' cannot be parsed as bool: %s", name, default);
              return nil, false;
            }
          }
        case int:
          entry.type = int;
          if default != "" {
            if v, ok := strconv.parse_int(default); ok {
              entry.default = v;
            } else {
              log.errorf("error: 'default' field tag for '%s' cannot be parsed as int: %s", name, default);
              return nil, false;
            }
          }
        case uint:
          entry.type = uint;
          if default != "" {
            if v, ok := strconv.parse_uint(default); ok {
              entry.default = v;
            } else {
              log.errorf("error: 'default' field tag for '%s' cannot be parsed as uint: %s", name, default);
              return nil, false;
            }
          }
        case i32:
          entry.type = i32;
          if default != "" {
            if v, ok := strconv.parse_i64(default); ok {
              if v < bits.I32_MIN || v > bits.I32_MAX {
                log.errorf("error: 'default' field tag for '%s' outside i32 range: %s", name, default);
                return nil, false;
              }
              entry.default = i32(v);
            } else {
              log.errorf("error: 'default' field tag for '%s' cannot be parsed as i32: %s", name, default);
              return nil, false;
            }
          }
        case u32:
          entry.type = u32;
          if default != "" {
            if v, ok := strconv.parse_u64(default); ok {
              if v > bits.U32_MAX {
                log.errorf("error: 'default' field tag for '%s' outside u32 range: %s", name, default);
                return nil, false;
              }
              entry.default = u32(v);
            } else {
              log.errorf("error: 'default' field tag for '%s' cannot be parsed as u32: %s", name, default);
              return nil, false;
            }
          }
        case i64:
          entry.type = i64;
          if default != "" {
            if v, ok := strconv.parse_i64(default); ok {
              entry.default = v;
            } else {
              log.errorf("error: 'default' field tag for '%s' cannot be parsed as i64: %s", name, default);
              return nil, false;
            }
          }
        case u64:
          entry.type = u64;
          if default != "" {
            if v, ok := strconv.parse_u64(default); ok {
              entry.default = v;
            } else {
              log.errorf("error: 'default' field tag for '%s' cannot be parsed as u64: %s", name, default);
              return nil, false;
            }
          }
        case rune:
          entry.type = rune;
          if default != "" {
            entry.default, _ = utf8.decode_rune_in_string(default);
          }
        case f32:
          entry.type = f32;
          if default != "" {
            if v, ok := strconv.parse_f32(default); ok {
              entry.default = v;
            } else {
              log.errorf("error: 'default' field tag for '%s' cannot be parsed as f32: %s", name, default);
              return nil, false;
            }
          }
        case f64:
          entry.type = f64;
          if default != "" {
            if v, ok := strconv.parse_f64(default); ok {
              entry.default = v;
            } else {
              log.errorf("error: 'default' field tag for '%s' cannot be parsed as f64: %s", name, default);
              return nil, false;
            }
          }
        case:
          log.errorf("error: type of '%s': %v -- not supported", name, type.id);
          return nil, false;
      }
      idx := len(args);
      append(&args, entry);
      if entry.short != 0 {
        parser.shorts[entry.short] = idx;
      }
      if entry.long != "" {
        parser.longs[entry.long] = idx;
      }
    }
  }
  parser.args = args[:];
  return parser, true;
}

new_parser :: proc(application: string, description: string, $T: typeid) -> (ArgParser(T), bool) {
  arena := new(mem.Arena);
  mem.init_arena(arena,make([]byte,2048*128));
  allocator := mem.arena_allocator(arena);
  context.allocator = allocator;
  parser, ok := process_struct(T);
  if !ok {
    return ArgParser(T){}, false;
  }
  argParser := ArgParser(T) {
    application = strings.clone(application),
    description = strings.clone(description),
    allocator = allocator,
    rootParser = parser,
  };
  return argParser, true;
}

parse_args :: proc(parser: ArgParser($T), target: ^T, args: []string) -> bool {
  return false;
}

short_arg_string :: proc(builder: ^strings.Builder, entry: ArgEntry) {
  close := "";
  if !entry.required {
    strings.write_string(builder,"[");
    close = "]";
  }
  if entry.short != 0 && entry.long != "" {
    strings.write_string(builder,"-");
    strings.write_rune_builder(builder,entry.short);
    strings.write_string(builder,"|");
    strings.write_string(builder,"--");
    strings.write_string(builder,entry.long);
  } else if entry.short != 0 {
    strings.write_string(builder,"-");
    strings.write_rune_builder(builder,entry.short);
  } else {
    strings.write_string(builder,"--");
    strings.write_string(builder,entry.long);
  }

  if entry.type != bool {
    strings.write_string(builder," ARG");
  }

  strings.write_string(builder,close);
}

short_arg_strings :: proc(entries: []ArgEntry) -> string {
  b := strings.make_builder();
  defer strings.destroy_builder(&b);

  for v in entries {
    fmt.printf("%v\n",v);
    short_arg_string(&b,v);
    strings.write_string(&b," ");
  }

  return strings.clone(strings.to_string(b));
}

print_help :: proc(parser: ArgParser($T), commands: ..string) {
  fmt.printf("%s\n", parser.application);
  fmt.printf("    %s\n\n", parser.description);
  fmt.println("Usage:");
  short_args := short_arg_strings(parser.rootParser.args);
  fmt.printf("%s %s\n", parser.application, short_args);
  delete(short_args);
}

delete_parser :: proc(argParser: ^ArgParser($T), allocator := context.allocator, loc := #caller_location) {
  free_all(argParser.allocator);
  arena := cast(^mem.Arena)argParser.allocator.data;
  delete(arena.data, allocator, loc);
  free((rawptr)(arena), allocator, loc);
}
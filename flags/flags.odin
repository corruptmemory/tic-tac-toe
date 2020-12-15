package flags

import "core:os"

Parser :: struct {

};

@(private)
add_short :: proc(parser: ^Parser, char: u8, description: string, T: typeid) {

}

@(private)
add_short_default :: proc(parser: ^Parser, char: u8, description: string, $T: typeid, default: T) {

}

@(private)
add_long :: proc(parser: ^Parser, char: u8, long: string, description: string, T: typeid) {

}

@(private)
add_long_default :: proc(parser: ^Parser, char: u8, long: string, description: string, $T: typeid, default: T) {

}

add_flag :: proc{add_short, add_short_default, add_long, add_long_default};

new_parser :: proc() -> Parser {
  return Parser{};
}
package main

import "flags"

CliArgs :: struct {
  a: int `short:"a" long:"a-name" description:"The A argument" required:"true"`,
  b: string `short:"a" long:"a-name" description:"The A argument" required:"true"`,
  c: u64 `short:"a" long:"a-name" description:"The A argument" required:"true"`,
  d: bool `short:"a" long:"a-name" description:"The A argument" required:"true"`,
};

main :: proc() {
  if parser, ok := flags.new_parser(CliArgs); ok {
    defer flags.delete_parser(&parser);
    _ = parser;
  }
}

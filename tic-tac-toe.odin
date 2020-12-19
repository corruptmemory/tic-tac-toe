package main

import "flags"

CliArgs :: struct {
  a: int `short:"a" long:"a-name" description:"The A argument" required:"true" default:"123"`,
  a1: int `short:"A" long:"a1-name" description:"The A1 argument"`,
  b: string `short:"b" long:"b-name" description:"The B argument" required:"true"`,
  c: u64 `short:"c" long:"c-name" description:"The C argument" required:"true"`,
  d: bool `long:"d-name" description:"The D argument" required:"true"`,
  e: struct {
    ea: u64 `short:"A" long:"ea-name" description:"The EA argument" required:"true"`,
  } `command:"e-cmd"` ,
};

main :: proc() {
  if parser, ok := flags.new_parser("tic-tac-toe", "The game of tic-tac-toe", CliArgs); ok {
    defer flags.delete_parser(&parser);
    flags.print_help(parser);
  }
}

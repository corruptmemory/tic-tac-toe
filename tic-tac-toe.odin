package main

import "flags"
import "core:log"
import "core:fmt"
import "core:time"
import "ui"
import "input"
import "core:thread"
import "tsync"
import "core:math/rand"

// CliArgs :: struct {
//   a: int `short:"a" long:"a-name" description:"The A argument" required:"true" default:"123"`,
//   a1: int `short:"A" long:"a1-name" description:"The A1 argument"`,
//   b: string `short:"b" long:"b-name" description:"The B argument" required:"true"`,
//   c: u64 `short:"c" long:"c-name" description:"The C argument" required:"true"`,
//   d: bool `long:"d-name" description:"The D argument" required:"true"`,
// };

print_ui_state :: proc(uiState: ^input.UIState) {
  changed: bool;

  for _, i in uiState.keys {
    if uiState.keys[i].changed {
      changed = true;
      break;
    }
  }

  if changed {
    fmt.println("***********");
    for _, i in uiState.keys {
      fmt.printf("%v: %v\n", uiState.keys[i].key, uiState.keys[i].upDown);
    }
  }
}



main :: proc() {
  uiState: input.UIState;
  input.init(&uiState);
  fmt.printf("uiState: %v\n", uiState);

  // if parser, ok := flags.new_parser("tic-tac-toe", "The game of tic-tac-toe", CliArgs); ok {
  //   defer flags.delete_parser(&parser);
  //   flags.print_help(parser);
  // }
  ctx : ui.Context;

  if ui.connect_display(&ctx, nil) {
    fmt.printf("Connected: %v\n", ctx.conn);
    defer ui.disconnect_display(&ctx);
    ui.init(&ctx);

    keyMap := ui.InputMap  {
      up = 'w',
      down = 's',
      left = 'a',
      right = 'd',
      select = ' ',
      exit = 'p',
    };

    if ok := ui.set_input_map(&ctx, keyMap); !ok {
      fmt.println("error: failed to set input map");
    }

    ui.start(&ctx);
    // ui.show_keyboard_mapping(&ctx);

    if w, wok := ui.create_window(&ctx); wok {
      for ui.get_input_state(&ctx,&uiState) {
        print_ui_state(&uiState);
        if input.should_exit(&uiState) {
          break;
        }
        time.nanosleep(1000000);
      }
      ui.shutdown(&ctx,w);
    }
  }
}

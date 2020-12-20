package main

import "flags"
import "core:log"
import "core:fmt"
import "ui"
import "shared:x11/xcb"

CliArgs :: struct {
  a: int `short:"a" long:"a-name" description:"The A argument" required:"true" default:"123"`,
  a1: int `short:"A" long:"a1-name" description:"The A1 argument"`,
  b: string `short:"b" long:"b-name" description:"The B argument" required:"true"`,
  c: u64 `short:"c" long:"c-name" description:"The C argument" required:"true"`,
  d: bool `long:"d-name" description:"The D argument" required:"true"`,
};

eventMask :: ~u8(0x80);

main :: proc() {
  context.logger = log.create_console_logger(lowest = log.Level.Error);
  if parser, ok := flags.new_parser("tic-tac-toe", "The game of tic-tac-toe", CliArgs); ok {
    defer flags.delete_parser(&parser);
    flags.print_help(parser);
  }
  ctx : ui.Context;
  if ui.connect_display(&ctx, nil) {
    fmt.printf("Connected: %v\n", ctx.conn);
    defer ui.disconnect_display(&ctx);
    ui.setup(&ctx);

    if _, wok := ui.create_window(&ctx); wok {
      for event := ui.wait_for_event(&ctx); event != nil; event = ui.wait_for_event(&ctx) {
        // fmt.printf("event: %v\n", event);
        evt := event.responseType & eventMask;
        switch evt {
          case xcb.KEY_PRESS:
            fmt.println("xcb.KEY_PRESS");
          case xcb.KEY_RELEASE:
            fmt.println("xcb.KEY_RELEASE");
          case xcb.BUTTON_PRESS:
            fmt.println("xcb.BUTTON_PRESS");
          case xcb.BUTTON_RELEASE:
            fmt.println("xcb.BUTTON_RELEASE");
          case xcb.MOTION_NOTIFY:
            fmt.println("xcb.MOTION_NOTIFY");
          case xcb.ENTER_NOTIFY:
            fmt.println("xcb.ENTER_NOTIFY");
          case xcb.LEAVE_NOTIFY:
            fmt.println("xcb.LEAVE_NOTIFY");
          case xcb.FOCUS_IN:
            fmt.println("xcb.FOCUS_IN");
          case xcb.FOCUS_OUT:
            fmt.println("xcb.FOCUS_OUT");
          case xcb.KEYMAP_NOTIFY:
            fmt.println("xcb.KEYMAP_NOTIFY");
          case xcb.EXPOSE:
            fmt.println("xcb.EXPOSE");
          case xcb.GRAPHICS_EXPOSURE:
            fmt.println("xcb.GRAPHICS_EXPOSURE");
          case xcb.NO_EXPOSURE:
            fmt.println("xcb.NO_EXPOSURE");
          case xcb.RESIZE_REQUEST:
            fmt.println("xcb.RESIZE_REQUEST");
          case xcb.VISIBILITY_NOTIFY:
            fmt.println("xcb.VISIBILITY_NOTIFY");
          case :
            fmt.printf("Got unexpected event type: %d\n", evt);
        }
        ui.free_event(event);
      }
    }
  }
}

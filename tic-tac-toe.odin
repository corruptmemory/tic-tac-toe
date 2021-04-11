package main

import "ui"
import "core:log"
import "core:os"
import sdl "shared:sdl2"
import "input"
import "graphics"

main :: proc() {
  context.logger = log.create_console_logger(lowest = log.Level.Debug);

  grCtx: graphics.Graphics_Context;
  if !graphics.graphics_init(&grCtx) {
    os.exit(-1);
  }
  defer graphics.graphics_destroy(&grCtx);

  // ctx: ui.UIContext;
  // if !ui.ui_init(&ctx) {
  //   os.exit(-1);
  // }
  // defer ui.ui_destroy(&ctx);

  if !graphics.graphics_create_window(ctx = &grCtx, width = 640, height = 480) {
    os.exit(-1);
  }
  if !ui.ui_draw_frame(&ctx, ctx.window) {
    os.exit(-1);
  }

  inputCtx: input.Input_Context;
  stop:
  for {
    events := input.input_get_inputs(&inputCtx);
    for events > 0 {
      for i in 0..<events {
        event := ctx.sdl_events[i];
        #partial switch event.type {
        case sdl.Event_Type.Quit:
          break stop;
        case sdl.Event_Type.Window_Event:
          #partial switch event.window.event {
          case sdl.Window_Event_ID.Resized:
            ctx.framebufferResized = true;
            ctx.width = u32(event.window.data1);
            ctx.height = u32(event.window.data2);
          case sdl.Window_Event_ID.Exposed:
          case sdl.Window_Event_ID.Shown:
          }
        case:
        }
      }
      sdl.update_window_surface(ctx.window);
      events = ui.ui_get_inputs(&ctx);
    }
    if events < 0 {
      log.errorf("Error getting input events: %v", ui.ui_get_error(&ctx));
      break stop;
    }

    if !ui.ui_draw_frame(&ctx, ctx.window) {
      break stop;
    }
  }
}

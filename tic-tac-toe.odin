package main

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

  if !graphics.graphics_create_window(ctx = &grCtx, width = 640, height = 480) {
    os.exit(-1);
  }
  if !graphics.graphics_draw_frame(&grCtx, grCtx.window) {
    os.exit(-1);
  }

  inputCtx: input.Input_Context;
  stop:
  for {
    events := input.input_get_inputs(&inputCtx);
    for events > 0 {
      for i in 0..<events {
        event := inputCtx.events[i];
        #partial switch event.type {
        case sdl.Event_Type.Quit:
          break stop;
        case sdl.Event_Type.Window_Event:
          #partial switch event.window.event {
          case sdl.Window_Event_ID.Resized:
            grCtx.framebufferResized = true;
            grCtx.width = u32(event.window.data1);
            grCtx.height = u32(event.window.data2);
          case sdl.Window_Event_ID.Exposed:
          case sdl.Window_Event_ID.Shown:
          }
        case:
        }
      }
      sdl.update_window_surface(grCtx.window);
      events = input.input_get_inputs(&inputCtx);
    }
    if events < 0 {
      log.errorf("Error getting input events: %v", input.input_get_error(&inputCtx));
      break stop;
    }

    if !graphics.graphics_draw_frame(&grCtx, grCtx.window) {
      break stop;
    }
  }
}

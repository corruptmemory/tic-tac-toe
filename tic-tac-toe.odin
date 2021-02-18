package main

import "ui"
import "core:log"
import "core:os"
import sdl "shared:sdl2"

main :: proc() {
  context.logger = log.create_console_logger(lowest = log.Level.Debug);
  ctx: ui.UIContext;
  if !ui.ui_init(&ctx) {
    os.exit(-1);
  }
  defer ui.ui_destroy(&ctx);
  if !ui.ui_create_window(ctx = &ctx, width = 640, height = 480) {
    os.exit(-1);
  }
  if !ui.ui_draw_frame(&ctx, ctx.window) {
    os.exit(-1);
  }

  stop:
  for {
    events := ui.ui_get_inputs(&ctx);
    for events > 0 {
      for i in 0..<events {
        event := ctx.sdl_events[i];
        log.debugf("Got event: %v", event);
        #partial switch event.type {
        case sdl.Event_Type.Quit:
          break stop;
        case sdl.Event_Type.Window_Event:
          #partial switch event.window.event {
          case sdl.Window_Event_ID.Resized:
            log.debug("RESIZED!!");
            ctx.framebufferResized = true;
            log.debugf("new size: %d %d\n",event.window.data1,event.window.data2);
            ctx.width = u32(event.window.data1);
            ctx.height = u32(event.window.data2);
          case sdl.Window_Event_ID.Exposed:
            log.debug("EXPOSED!!");
          case sdl.Window_Event_ID.Shown:
            log.debug("SHOWN!!");
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

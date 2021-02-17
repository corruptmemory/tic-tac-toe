package main

import "ui"
import "core:log"
import "core:os"

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
  if !ui.ui_loop(&ctx) {
    os.exit(-1);
  }
}

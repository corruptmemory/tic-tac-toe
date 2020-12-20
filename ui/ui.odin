package ui

import "shared:x11/xcb"
import "core:mem"
import "core:os"

Context :: struct {
  conn: ^xcb.Connection,
  setup: ^xcb.Setup,
  screen: ^xcb.Screen,
}

Window :: struct {
  id: u32,

}

connect_display :: proc(ctx: ^Context, display: cstring) -> bool {
  ctx.conn = xcb.connect(display,nil);
  if ctx.conn == nil {
    return false;
  }

  return true;
}

setup :: proc(ctx: ^Context) {
  ctx.setup = xcb.get_setup(ctx.conn);
  ctx.screen = xcb.setup_roots_iterator(ctx.setup).data;
}

create_window :: proc(ctx: ^Context,) -> (Window, bool) {
  window := Window {
    id = xcb.generate_id(ctx.conn),
  };
  mask := u32(xcb.Cw.EventMask);
  eventMasks := []i32{
    i32(xcb.EventMask.KeyPress |
    xcb.EventMask.KeyRelease |
    xcb.EventMask.ButtonPress |
    xcb.EventMask.ButtonRelease |
    xcb.EventMask.PointerMotion |
    xcb.EventMask.Exposure |
    xcb.EventMask.VisibilityChange |
    xcb.EventMask.FocusChange |
    xcb.EventMask.ResizeRedirect)
  };
  _ = xcb.create_window(
        c = ctx.conn,
        depth = xcb.COPY_FROM_PARENT,
        wid = window.id,
        parent = ctx.screen^.root,
        x = 100,
        y = 100,
        width = 521,
        height = 521,
        borderWidth = 10,
        class = u16(xcb.WindowClass.InputOutput),
        visual = ctx.screen^.rootVisual,
        valueMask = mask,
        valueList = mem.raw_slice_data(eventMasks)
    );

  _ = xcb.map_window(ctx.conn, window.id);
  _ = xcb.flush (ctx.conn);
  return window, true;
}


disconnect_display :: proc(ctx: ^Context) {
  xcb.disconnect(ctx.conn);
}

wait_for_event :: proc(ctx: ^Context) -> ^xcb.GenericEvent {
  return xcb.wait_for_event(ctx.conn);
}

free_event :: proc(event: ^xcb.GenericEvent) {
  os.heap_free(event);
}


package input

import "core:log"
import bc "../build_config"

when bc.TOOLKIT == "sdl2" {
  import sdl "shared:sdl2"
  import graphics "../graphics"

  ui_loop :: proc(ctx: ^graphics.GraphicsContext) -> bool {
    event: sdl.Event;
    stop:
    for {
      for sdl.poll_event(&event) != 0 {
        #partial switch event.type {
        case sdl.Event_Type.Quit:
          break stop;
        case sdl.Event_Type.Window_Event:
          #partial switch event.window.event {
          case sdl.Window_Event_ID.Resized:
            log.debug("RESIZED!!");
            log.debugf("new size: %d %d\n",event.window.data1,event.window.data2);
            ctx.width = u32(event.window.data1);
            ctx.height = u32(event.window.data2);
            sdl.update_window_surface(ctx.window);
          case sdl.Window_Event_ID.Exposed:
            log.debug("EXPOSED!!");
            sdl.update_window_surface(ctx.window);
          case sdl.Window_Event_ID.Shown:
            log.debug("SHOWN!!");
            sdl.update_window_surface(ctx.window);
          }
        case:
        }
      }
    }
    return true;
  }

}
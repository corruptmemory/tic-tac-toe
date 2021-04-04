package input

import bc "../build_config"

when bc.TOOLKIT == "sdl2" {
  import sdl "shared:sdl2"
  import "core:mem"

  MAX_SDL_EVENTS :: 10;

  Input_Context :: struct {
    events: [MAX_SDL_EVENTS]sdl.Event,
  };

  input_get_inputs :: proc(input_ctx: ^Input_Context) -> i32 {
    sdl.pump_events();
    return sdl.peep_events(mem.raw_array_data(&input_ctx.events),
                           MAX_SDL_EVENTS,
                           sdl.Event_Action.Get_Event,
                           u32(sdl.Event_Type.First_Event),
                           u32(sdl.Event_Type.Last_Event));
  }

}
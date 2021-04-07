package graphics
import vk "shared:vulkan"
import "core:log"
import bc "../build_config"

when bc.TOOLKIT == "sdl2" {
  import sdl "shared:sdl2"
  import rt "core:runtime"

  WINDOW_TYPE :: ^sdl.Window;

  sdl_pixeltype_packed32 :: 6;
  sdl_packedorder_rgba :: 5;
  sdl_packedlayout_8888 :: 6;

  sdl_define_pixelformat :: proc(type, order , layout, bits, bytes: u32) -> u32 {
      return ((1 << 28) | ((type) << 24) | ((order) << 20) | ((layout) << 16) | ((bits) << 8) | ((bytes) << 0));
  }

  sdl_pixelformat_rgba8888 := sdl_define_pixelformat(sdl_pixeltype_packed32, sdl_packedorder_rgba, sdl_packedlayout_8888, 32, 4);

  graphics_create_surface :: proc(ctx: ^Graphics_Context) -> bool {
    surface: vk.SurfaceKHR;
    createInfo : vk.XlibSurfaceCreateInfoKHR;
    createInfo.sType = vk.StructureType.XlibSurfaceCreateInfoKhr;
    info : sdl.Sys_Wm_Info;
    sdl.get_version(&info.version);
    if sdl.get_window_wm_info(ctx.window, &info) == sdl.Bool.False {
      log.error("Could not get window info.");
      return false;
    }
    log.debugf("WOOT!  Got Window info: %v", info);
    createInfo.dpy = info.info.x11.display;
    createInfo.window = info.info.x11.window;
    result := vk.create_xlib_surface_khr(ctx.instance, &createInfo, nil, &surface);
    if result != vk.Result.Success {
      log.errorf("Failed to create surface: ", result);
      return false;
    }
    ctx.surface = surface;
    return true;
  }

  graphics_get_error :: proc(ctx: ^Graphics_Context) -> string {
    err := sdl.get_error();
    return rt.cstring_to_string(err);
  }
}
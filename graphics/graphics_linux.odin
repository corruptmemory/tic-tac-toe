package graphics
import vk "shared:vulkan"
import "core:log"
import bc "../build_config"

when bc.TOOLKIT == "sdl2" {
  import sdl "shared:sdl2"
  import img "shared:sdl2/image"
  import rt "core:runtime"
  import "core:strings"
  import "core:mem"
  import "core:math/bits"

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

  graphics_create_window :: proc(ctx: ^Graphics_Context,
                                 name: string = "tic-tac-toe",
                                 x: i32 = cast(i32)sdl.Window_Pos.Undefined,
                                 y: i32 = cast(i32)sdl.Window_Pos.Undefined,
                                 width: u32,
                                 height: u32,
                                 flags: sdl.Window_Flags = sdl.Window_Flags.Shown | sdl.Window_Flags.Vulkan | sdl.Window_Flags.Resizable) -> bool
  {
    cname := strings.clone_to_cstring(name, context.temp_allocator);
    window := sdl.create_window(cname, x, y, i32(width), i32(height), flags);
    if window == nil {
      log.errorf("could not create window: {}\n", sdl.get_error());
      return false;
    }
    ctx.window = window;
    ctx.width = width;
    ctx.height = height;

    if !graphics_load_geometry(ctx) do return false;
    if !graphics_create_surface(ctx) do return false;
    if !graphics_find_queue_families(ctx) do return false;
    if !graphics_create_logical_device(ctx) do return false;
    if !graphics_query_swap_chain_support(ctx) do return false;
    if !graphics_create_swap_chain(ctx) do return false;
    if !graphics_create_image_views(ctx) do return false;
    if !graphics_create_render_pass(ctx) do return false;
    if !graphics_create_descriptor_layout(ctx) do return false;
    if !graphics_create_graphics_pipeline(ctx) do return false;
    if !graphics_create_command_pool(ctx) do return false;
    if !graphics_prepare_instance_data(ctx) do return false;
    if !graphics_create_depth_resources(ctx) do return false;
    if !graphics_create_framebuffers(ctx) do return false;
    if !graphics_create_texture_image(ctx) do return false;
    if !graphics_create_texture_image_view(ctx) do return false;
    if !graphics_create_texture_sampler(ctx) do return false;
    if !graphics_create_vertex_buffer(ctx, &ctx.piece) do return false;
    if !graphics_create_vertex_buffer(ctx, &ctx.board) do return false;
    if !graphics_create_index_buffer(ctx, &ctx.piece) do return false;
    if !graphics_create_index_buffer(ctx, &ctx.board) do return false;
    if !graphics_create_uniform_buffers(ctx) do return false;
    if !graphics_create_descriptor_pool(ctx) do return false;
    if !graphics_create_descriptor_sets(ctx) do return false;
    if !graphics_create_command_buffers(ctx) do return false;
    if !graphics_create_sync_objects(ctx) do return false;

    return true;
  }


  graphics_draw_frame :: proc(ctx: ^Graphics_Context, window: ^sdl.Window) -> bool {
    vk.wait_for_fences(ctx.device, 1, &ctx.inFlightFences[ctx.currentFrame], vk.TRUE, bits.U64_MAX);

    imageIndex: u32;
    #partial switch vk.acquire_next_image_khr(ctx.device, ctx.swapChain, bits.U64_MAX, ctx.imageAvailableSemaphores[ctx.currentFrame], nil, &imageIndex) {
      case vk.Result.ErrorOutOfDateKhr, vk.Result.SuboptimalKhr:
        return graphics_recreate_swap_chain(ctx);
      case vk.Result.Success:
      // nothing
      case:
        log.error("Error: what am I doing here?");
        return false;
    }

    graphics_update_uniform_buffer(ctx, imageIndex);

    if ctx.imagesInFlight[imageIndex] != nil {
      vk.wait_for_fences(ctx.device, 1, &ctx.imagesInFlight[imageIndex], vk.TRUE, bits.U64_MAX);
    }
    ctx.imagesInFlight[imageIndex] = ctx.inFlightFences[ctx.currentFrame];

    waitSemaphores := []vk.Semaphore{ctx.imageAvailableSemaphores[ctx.currentFrame]};
    waitStages := []vk.PipelineStageFlags{u32(vk.PipelineStageFlagBits.ColorAttachmentOutput)};
    signalSemaphores := []vk.Semaphore{ctx.renderFinishedSemaphores[ctx.currentFrame]};


    submitInfo := vk.SubmitInfo{
      sType = vk.StructureType.SubmitInfo,
      waitSemaphoreCount = 1,
      pWaitSemaphores = mem.raw_slice_data(waitSemaphores),
      pWaitDstStageMask = mem.raw_slice_data(waitStages),
      commandBufferCount = 1,
      pCommandBuffers = &ctx.commandBuffers[imageIndex],
      signalSemaphoreCount = 1,
      pSignalSemaphores = mem.raw_slice_data(signalSemaphores),
    };

    vk.reset_fences(ctx.device, 1, &ctx.inFlightFences[ctx.currentFrame]);

    if vk.queue_submit(ctx.graphicsQueue, 1, &submitInfo, ctx.inFlightFences[ctx.currentFrame]) != vk.Result.Success {
      return false;
    }

    swapChains := []vk.SwapchainKHR{ctx.swapChain};
    presentInfo := vk.PresentInfoKHR{
      sType = vk.StructureType.PresentInfoKhr,
      waitSemaphoreCount = 1,
      pWaitSemaphores = mem.raw_slice_data(signalSemaphores),
      swapchainCount = 1,
      pSwapchains = mem.raw_slice_data(swapChains),
      pImageIndices = &imageIndex,
    };

    result := vk.queue_present_khr(ctx.presentQueue, &presentInfo);

    if result == vk.Result.ErrorOutOfDateKhr || result == vk.Result.SuboptimalKhr || ctx.framebufferResized {
      ctx.framebufferResized = false;
      if !graphics_recreate_swap_chain(ctx) {
        log.error("failed to recreate swap chain");
        return false;
      }
      return true;
    } else if result != vk.Result.Success {
      return false;
    }

    ctx.currentFrame = (ctx.currentFrame + 1) % max_frames_in_flight;
    return true;
  }


  graphics_create_texture_image :: proc(ctx: ^Graphics_Context) -> bool {
    origImageSurface := img.load("blender/viking_room.png");
    if origImageSurface == nil {
      log.error("Error loading texture image");
      return false;
    }
    defer sdl.free_surface(origImageSurface);
    texWidth := origImageSurface.w;
    texHeight := origImageSurface.h;
    targetSurface := sdl.create_rgb_surface_with_format(0, origImageSurface.w, origImageSurface.h, 32, sdl_pixelformat_rgba8888);
    defer sdl.free_surface(targetSurface);
    rect := sdl.Rect {
      x = 0,
      y = 0,
      w = origImageSurface.w,
      h = origImageSurface.h,
    };
    err := sdl.upper_blit(origImageSurface,&rect,targetSurface,&rect);
    if err != 0 {
      log.errorf("Error blitting texture image to target surface: %d", err);
      return false;
    }
    // render_image(targetSurface);
    imageSize : vk.DeviceSize = u64(texWidth * texHeight * 4);
    stagingBuffer : vk.Buffer;
    stagingBufferMemory : vk.DeviceMemory;

    if !graphics_create_buffer(ctx, imageSize, vk.BufferUsageFlagBits.TransferSrc, vk.MemoryPropertyFlagBits.HostVisible | vk.MemoryPropertyFlagBits.HostCoherent, &stagingBuffer, &stagingBufferMemory) {
      log.error("Error: failed to create texture buffer");
      return false;
    }
    defer vk.destroy_buffer(ctx.device, stagingBuffer, nil);
    defer vk.free_memory(ctx.device, stagingBufferMemory, nil);

    data: rawptr;
    vk.map_memory(ctx.device, stagingBufferMemory, 0, imageSize, 0, &data);
    sdl.lock_surface(targetSurface);
    rt.mem_copy_non_overlapping(data, targetSurface.pixels, int(imageSize));
    sdl.unlock_surface(targetSurface);
    vk.unmap_memory(ctx.device, stagingBufferMemory);

    if !graphics_create_image(ctx, u32(texWidth), u32(texHeight), vk.Format.R8G8B8A8Srgb,vk.ImageTiling.Optimal, vk.ImageUsageFlagBits.TransferDst | vk.ImageUsageFlagBits.Sampled, vk.MemoryPropertyFlagBits.DeviceLocal, &ctx.texture_image, &ctx.texture_image_memory) {
      log.error("Error: could not create image");
      return false;
    }

    if !graphics_transition_image_layout(ctx, ctx.texture_image, vk.Format.R8G8B8A8Srgb, vk.ImageLayout.Undefined, vk.ImageLayout.TransferDstOptimal) {
      log.error("Error: could not create transition image layout");
      return false;
    }
    graphics_copy_buffer_to_image(ctx, stagingBuffer, ctx.texture_image, u32(texWidth), u32(texHeight));
    if !graphics_transition_image_layout(ctx, ctx.texture_image, vk.Format.R8G8B8A8Srgb, vk.ImageLayout.TransferDstOptimal, vk.ImageLayout.ShaderReadOnlyOptimal) {
      log.error("Error: could not create tranition image layout");
      return false;
    }

    return true;
  }
}
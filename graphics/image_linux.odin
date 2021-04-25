package graphics

import vk "shared:vulkan"
import "core:log"
import bc "../build_config"

when bc.TOOLKIT == "sdl2" {
  import sdl "shared:sdl2"
  import img "shared:sdl2/image"
  import rt "core:runtime"
  import "core:strings"

  image_load_image_from_file :: proc(image: ^Image,
                                     file: string,
                                     command_pool: vk.CommandPool,
                                     queue: vk.Queue,
                                     image_type: vk.ImageType = vk.ImageType._2D,
                                     properties: vk.MemoryPropertyFlagBits = vk.MemoryPropertyFlagBits.DeviceLocal,
                                     format: vk.Format = vk.Format.B8G8R8A8Unorm,
                                     usage: vk.ImageUsageFlags = u32(vk.ImageUsageFlagBits.TransferDst | vk.ImageUsageFlagBits.Sampled),
                                     mip_levels: u32 = 1,
                                     array_layers: u32 = 1,
                                     tiling: vk.ImageTiling = vk.ImageTiling.Optimal,
                                     flags: vk.ImageCreateFlags = 0,
                                     samples: vk.SampleCountFlagBits = vk.SampleCountFlagBits._1,
                                     queue_families: []u32 = nil,
                                     sdl_pixel_format: u32 = sdl_pixelformat_rgba8888) -> bool {
    fn := strings.clone_to_cstring(file);
    defer delete(fn);
    orig_image_surface := img.load(fn);
    if orig_image_surface == nil {
      log.error("Error loading texture image");
      return false;
    }
    defer sdl.free_surface(orig_image_surface);
    image_width := orig_image_surface.w;
    image_height := orig_image_surface.h;
    target_surface := sdl.create_rgb_surface_with_format(0, image_width, image_height, 32, sdl_pixel_format);
    log.debug("We got the target surface.");
    defer sdl.free_surface(target_surface);
    rect := sdl.Rect {
      x = 0,
      y = 0,
      w = image_width,
      h = image_height,
    };
    err := sdl.upper_blit(orig_image_surface,&rect,target_surface,&rect);
    log.debug("Blittage!");
    if err != 0 {
      log.errorf("Error blitting texture image to target surface: %d", err);
      return false;
    }

    image_size : vk.DeviceSize = u64(image_width * image_height * auto_cast target_surface.format.bytes_per_pixel);
    log.debugf("Let me guess, we have a 0 image size: %d", image_size);
    staging_buffer : vk.Buffer;
    staging_buffer_memory : vk.DeviceMemory;

    log.debug("before vk_create_buffer");
    if !vk_create_buffer(image.device, image.physical_device, image_size, vk.BufferUsageFlagBits.TransferSrc, vk.MemoryPropertyFlagBits.HostVisible | vk.MemoryPropertyFlagBits.HostCoherent, &staging_buffer, &staging_buffer_memory) {
      log.error("Error: failed to create texture buffer");
      return false;
    }
    defer vk.destroy_buffer(image.device, staging_buffer, nil);
    defer vk.free_memory(image.device, staging_buffer_memory, nil);
    log.debug("after vk_create_buffer");

    data: rawptr;
    vk.map_memory(image.device, staging_buffer_memory, 0, image_size, 0, &data);
    log.debug("Mappage!");
    sdl.lock_surface(target_surface);
    log.debug("Lockage!");
    rt.mem_copy_non_overlapping(data, target_surface.pixels, auto_cast image_size);
    log.debug("Copyage!");
    sdl.unlock_surface(target_surface);
    log.debug("Unlockage!");
    vk.unmap_memory(image.device, staging_buffer_memory);
    log.debug("Unmappage!");


    log.debug("append(&image.mipmap, Mipmap{extent = vk.Extent3D{width = u32(image_width), height = u32(image_height), depth = 1}});");
    append(&image.mipmap, Mipmap{extent = vk.Extent3D{width = u32(image_width), height = u32(image_height), depth = 1}});

    if !image_create_vk_image(image = image,
                              image_type = image_type,
                              properties = properties,
                              format = format,
                              usage = usage,
                              mip_levels = mip_levels,
                              array_layers = array_layers,
                              tiling = tiling,
                              flags = flags,
                              samples = samples,
                              queue_families = queue_families) {
      log.error("Error: could not create image");
      return false;
    }

    log.debug("But why can't we keep going?");

    if !image_transition_image_layout(image = image,
                                      command_pool = command_pool,
                                      queue = queue,
                                      old_layout = vk.ImageLayout.Undefined,
                                      new_layout = vk.ImageLayout.TransferDstOptimal) {
      log.error("Error: could not create transition image layout");
      return false;
    }
    log.debug("It certainly seems like we can!");
    image_copy_buffer_to_image(image, command_pool, queue, staging_buffer);
    log.debug("The show must go on!");
    if !image_transition_image_layout(image = image,
                                      command_pool = command_pool,
                                      queue = queue,
                                      old_layout = vk.ImageLayout.TransferDstOptimal,
                                      new_layout = vk.ImageLayout.ShaderReadOnlyOptimal) {
      log.error("Error: could not create tranition image layout");
      return false;
    }
    log.debug("We did it!  We got to the end!");

    return true;
  }
}
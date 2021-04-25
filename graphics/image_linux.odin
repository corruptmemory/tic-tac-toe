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
    defer sdl.free_surface(target_surface);
    rect := sdl.Rect {
      x = 0,
      y = 0,
      w = image_width,
      h = image_height,
    };
    err := sdl.upper_blit(orig_image_surface,&rect,target_surface,&rect);
    if err != 0 {
      log.errorf("Error blitting texture image to target surface: %d", err);
      return false;
    }

    image_size : vk.DeviceSize = u64(image_width * image_height * auto_cast target_surface.format.bytes_per_pixel);
    staging_buffer : vk.Buffer;
    staging_buffer_memory : vk.DeviceMemory;

    if !vk_create_buffer(image.device, image.physical_device, image_size, vk.BufferUsageFlagBits.TransferSrc, vk.MemoryPropertyFlagBits.HostVisible | vk.MemoryPropertyFlagBits.HostCoherent, &staging_buffer, &staging_buffer_memory) {
      log.error("Error: failed to create texture buffer");
      return false;
    }
    defer vk.destroy_buffer(image.device, staging_buffer, nil);
    defer vk.free_memory(image.device, staging_buffer_memory, nil);

    data: rawptr;
    vk.map_memory(image.device, staging_buffer_memory, 0, image_size, 0, &data);
    sdl.lock_surface(target_surface);
    rt.mem_copy_non_overlapping(data, target_surface.pixels, auto_cast image_size);
    sdl.unlock_surface(target_surface);
    vk.unmap_memory(image.device, staging_buffer_memory);

    if !graphics_create_image(ctx, u32(image_width), u32(image_height), vk.Format.R8G8B8A8Srgb,vk.ImageTiling.Optimal, vk.ImageUsageFlagBits.TransferDst | vk.ImageUsageFlagBits.Sampled, vk.MemoryPropertyFlagBits.DeviceLocal, &ctx.texture_image, &ctx.texture_image_memory) {
      log.error("Error: could not create image");
      return false;
    }

    if !graphics_transition_image_layout(ctx, ctx.texture_image, vk.Format.R8G8B8A8Srgb, vk.ImageLayout.Undefined, vk.ImageLayout.TransferDstOptimal) {
      log.error("Error: could not create transition image layout");
      return false;
    }
    graphics_copy_buffer_to_image(ctx, stagingBuffer, ctx.texture_image, u32(image_width), u32(image_height));
    if !graphics_transition_image_layout(ctx, ctx.texture_image, vk.Format.R8G8B8A8Srgb, vk.ImageLayout.TransferDstOptimal, vk.ImageLayout.ShaderReadOnlyOptimal) {
      log.error("Error: could not create tranition image layout");
      return false;
    }

    return true;
  }
}
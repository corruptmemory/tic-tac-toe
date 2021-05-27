package graphics

import vk "shared:vulkan"
import "core:strings"
import "core:mem"
import "core:log"

Mipmap :: struct {
  /// Mipmap level
  level: u32,

  /// Byte offset used for uploading
  offset: u32,

  /// Width depth and height of the mipmap
  extent: vk.Extent3D,
};

Image :: struct {
  device: vk.Device,
  physical_device: vk.PhysicalDevice,
  name: string,
  data: [dynamic]byte,
  format: vk.Format,
  layers: u32,
  mipmap: [dynamic]Mipmap,
  subresource: vk.ImageSubresource,
  vk_image: vk.Image,
  vk_image_memory: vk.DeviceMemory,
  allocator: mem.Allocator,
};

Image_View :: struct {
  device: vk.Device,
  physical_device: vk.PhysicalDevice,
  name: string,
  data: [dynamic]byte,
  format: vk.Format,
  layers: u32,
  mipmap: [dynamic]Mipmap,
  vk_image_view: vk.ImageView,
  allocator: mem.Allocator,
};

image_init :: proc(image: ^Image,
                   device: vk.Device,
                   physical_device: vk.PhysicalDevice,
                   name: string,
                   allocator := context.allocator) {
  image.device = device;
  image.physical_device = physical_device;
  image.allocator = allocator;
  image.name = strings.clone(name, allocator);
}

image_get_extent :: proc(image: ^Image) -> vk.Extent3D {
  return image.mipmap[0].extent;
}

image_create_vk_image :: proc(image: ^Image,
                              image_type: vk.ImageType = vk.ImageType._2D,
                              properties: vk.MemoryPropertyFlagBits = vk.MemoryPropertyFlagBits.DeviceLocal,
                              format: vk.Format = vk.Format.B8G8R8A8Unorm,
                              usage: vk.ImageUsageFlags = u32(vk.ImageUsageFlagBits.TransferDst | vk.ImageUsageFlagBits.Sampled),
                              mip_levels: u32 = 1,
                              array_layers: u32 = 1,
                              tiling: vk.ImageTiling = vk.ImageTiling.Optimal,
                              flags: vk.ImageCreateFlags = 0,
                              samples: vk.SampleCountFlagBits = vk.SampleCountFlagBits._1,
                              queue_families: []u32 = nil) -> bool {

  if mip_levels == 0 {
    log.error("Image should have at least one level");
    return false;
  }
  if array_layers == 0 {
    log.error("Image should have at least one layer");
    return false;
  }

  image.subresource.mipLevel   = mip_levels;
  image.subresource.arrayLayer = array_layers;

  image_info := vk.ImageCreateInfo {
    sType         = vk.StructureType.ImageCreateInfo,
    imageType     = image_type,
    extent        = image_get_extent(image),
    mipLevels     = mip_levels,
    arrayLayers   = array_layers,
    format        = format,
    tiling        = tiling,
    initialLayout = vk.ImageLayout.Undefined,
    usage         = usage,
    sharingMode   = vk.SharingMode.Exclusive,
    samples       = samples,
    flags         = flags,
  };

  if len(queue_families) > 0 {
    image_info.sharingMode           = vk.SharingMode.Concurrent;
    image_info.queueFamilyIndexCount = auto_cast len(queue_families);
    image_info.pQueueFamilyIndices   = mem.raw_slice_data(queue_families);
  }

  if vk_fail(vk.create_image(image.device, &image_info, nil, &image.vk_image)) {
    log.error("Failed to create image for the texture map");
    return false;
  }

  mem_requirements: vk.MemoryRequirements;
  vk.get_image_memory_requirements(image.device, image.vk_image, &mem_requirements);

  mt, ok := vk_find_memory_type(image.physical_device, mem_requirements.memoryTypeBits, auto_cast properties);
  if !ok {
    log.error("Error: failed to find memory");
    return false;
  }

  alloc_info := vk.MemoryAllocateInfo {
    sType = vk.StructureType.MemoryAllocateInfo,
    allocationSize = mem_requirements.size,
    memoryTypeIndex = mt,
  };

  if vk_fail(vk.allocate_memory(image.device, &alloc_info, nil, &image.vk_image_memory)) {
    log.error("Error: failed to allocate memory in device");
    return false;
  }

  if vk_fail(vk.bind_image_memory(image.device, image.vk_image, image.vk_image_memory, 0)) {
    log.error("Error: failed to bind memory to device");
    return false;
  }

  return true;
}

image_destroy :: proc(image: ^Image) {
  if image.name != "" do delete(image.name, image.allocator);
  if image.data != nil {
    delete(image.data);
    image.data = nil;
  }
  if image.mipmap != nil {
    delete(image.mipmap);
    image.mipmap = nil;
  }
  if image.vk_image != nil {
    vk.destroy_image(image.device, image.vk_image, nil);
    image.vk_image = nil;
  }
  if image.vk_image_memory != nil {
    vk.free_memory(image.device, image.vk_image_memory, nil);
    image.vk_image_memory = nil;
  }
}

image_copy_buffer_to_image :: proc(image: ^Image,
                                   command_pool: vk.CommandPool,
                                   queue: vk.Queue,
                                   buffer: vk.Buffer) {
  command_buffer := vk_begin_single_time_commands(image.device, command_pool);

  region := vk.BufferImageCopy{
    bufferOffset        = 0,
    bufferRowLength     = 0,
    bufferImageHeight   = 0,
    imageSubresource = {
      aspectMask     = u32(vk.ImageAspectFlagBits.Color),
      mipLevel       = 0,
      baseArrayLayer = 0,
      layerCount     = 1,
    },
    imageOffset         = {0, 0, 0},
    imageExtent         = image.mipmap[0].extent,
  };

  vk.cmd_copy_buffer_to_image(command_buffer, buffer, image.vk_image, vk.ImageLayout.TransferDstOptimal, 1, &region);

  vk_end_single_time_commands(image.device,
                              command_pool,
                              queue,
                              &command_buffer);
}

image_transition_image_layout :: proc(image: ^Image,
                                      command_pool: vk.CommandPool,
                                      queue: vk.Queue,
                                      old_layout: vk.ImageLayout,
                                      new_layout: vk.ImageLayout) -> bool {
  command_buffer := vk_begin_single_time_commands(image.device, command_pool);

  ufi : i32 = vk.QUEUE_FAMILY_IGNORED;

  barrier := vk.ImageMemoryBarrier {
    sType = vk.StructureType.ImageMemoryBarrier,
    oldLayout = old_layout,
    newLayout = new_layout,
    srcQueueFamilyIndex = transmute(u32)(ufi),
    dstQueueFamilyIndex = transmute(u32)(ufi),
    image = image.vk_image,
    subresourceRange = vk.ImageSubresourceRange{
      aspectMask = u32(vk.ImageAspectFlagBits.Color),
      baseMipLevel = 0,
      levelCount = 1,
      baseArrayLayer = 0,
      layerCount = 1,
    },
  };

  source_stage: vk.PipelineStageFlags;
  destination_stage: vk.PipelineStageFlags;

  if old_layout == vk.ImageLayout.Undefined && new_layout == vk.ImageLayout.TransferDstOptimal {
    barrier.srcAccessMask = 0;
    barrier.dstAccessMask = u32(vk.AccessFlagBits.TransferWrite);
    source_stage = u32(vk.PipelineStageFlagBits.TopOfPipe);
    destination_stage = u32(vk.PipelineStageFlagBits.Transfer);
  } else if old_layout == vk.ImageLayout.TransferDstOptimal && new_layout == vk.ImageLayout.ShaderReadOnlyOptimal {
    barrier.srcAccessMask = u32(vk.AccessFlagBits.TransferWrite);
    barrier.dstAccessMask = u32(vk.AccessFlagBits.ShaderRead);
    source_stage = u32(vk.PipelineStageFlagBits.Transfer);
    destination_stage = u32(vk.PipelineStageFlagBits.FragmentShader);
  } else if old_layout == vk.ImageLayout.Undefined && new_layout == vk.ImageLayout.DepthStencilAttachmentOptimal {
    barrier.srcAccessMask = 0;
    barrier.dstAccessMask = u32(vk.AccessFlagBits.DepthStencilAttachmentRead | vk.AccessFlagBits.DepthStencilAttachmentWrite);
    source_stage = u32(vk.PipelineStageFlagBits.TopOfPipe);
    destination_stage = u32(vk.PipelineStageFlagBits.EarlyFragmentTests);
  } else {
    log.error("Error: unsupported layout transition!");
    return false;
  }

  vk.cmd_pipeline_barrier(
    command_buffer,
    source_stage, destination_stage,
    0,
    0, nil,
    0, nil,
    1, &barrier,
  );

  vk_end_single_time_commands(image.device,
                              command_pool,
                              queue,
                              &command_buffer);

  return true;
}

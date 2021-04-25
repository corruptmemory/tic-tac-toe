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
  name: string,
  data: [dynamic]byte,
  format: vk.Format,
  layers: u32,
  mipmap: [dynamic]Mipmap,
  vk_image: vk.Image,
  vk_image_memory: vk.DeviceMemory,
  vk_image_view: vk.ImageView,
  allocator: mem.Allocator,
};

image_init :: proc(image: ^Image,
                   name: string,
                   data: []byte,
                   mipmap: []Mipmap,
                   format: vk.Format = vk.Format.B8G8R8A8Unorm) {
  resize(&image.data, len(data));
  copy(image.data[:], data);
  image.name = strings.clone(name);
  resize(&image.mipmap, len(mipmap));
  copy(image.mipmap[:], mipmap);
  image.format = format;
  image.layers = 1;
  image.allocator = context.allocator;
}

image_init_allocator :: proc(image: ^Image,
                             name: string,
                             data: []byte,
                             mipmap: []Mipmap,
                             format: vk.Format = vk.Format.B8G8R8A8Unorm,
                             allocator := context.allocator) {
  image.allocator = allocator;
  image.data.allocator = allocator;
  resize(&image.data, len(data));
  copy(image.data[:], data);
  image.name = strings.clone(name, image.allocator);
  image.mipmap.allocator = allocator;
  resize(&image.mipmap, len(mipmap));
  copy(image.mipmap[:], mipmap);
  image.layers = 1;
  image.format = format;
}


image_get_extent :: proc(image: ^Image) -> vk.Extent3D {
  return image.mipmap[0].extent;
}

image_clear_data :: proc(image: ^Image) {
  context.allocator = image.allocator;
  if image.data != nil {
    delete(image.data);
    image.data = nil;
  }
}

image_create_vk_image :: proc(image: ^Image,
                              device: vk.Device,
                              physical_device: vk.PhysicalDevice,
                              image_view_type: vk.ImageViewType,
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

  image_info := vk.ImageCreateInfo {
    sType = vk.StructureType.ImageCreateInfo,
    imageType = vk.ImageType._2D,
    extent = image_get_extent(image),
    mipLevels = mip_levels,
    arrayLayers = array_layers,
    format = format,
    tiling = tiling,
    initialLayout = vk.ImageLayout.Undefined,
    usage = usage,
    sharingMode = vk.SharingMode.Exclusive,
    samples = samples,
    flags = flags,
  };

  if len(queue_families) > 0 {
    image_info.sharingMode           = vk.SharingMode.Concurrent;
    image_info.queueFamilyIndexCount = auto_cast len(queue_families);
    image_info.pQueueFamilyIndices   = mem.raw_slice_data(queue_families);
  }

  if vk_fail(vk.create_image(device, &image_info, nil, &image.vk_image)) {
    log.error("Failed to create image for the texture map");
    return false;
  }

  mem_requirements: vk.MemoryRequirements;
  vk.get_image_memory_requirements(device, image.vk_image, &mem_requirements);

  mt, ok := vk_find_memory_type(physical_device, mem_requirements.memoryTypeBits, auto_cast properties);
  if !ok {
    log.error("Error: failed to find memory");
    return false;
  }

  alloc_info := vk.MemoryAllocateInfo {
    sType = vk.StructureType.MemoryAllocateInfo,
    allocationSize = mem_requirements.size,
    memoryTypeIndex = mt,
  };

  if vk_fail(vk.allocate_memory(device, &alloc_info, nil, &image.vk_image_memory)) {
    log.error("Error: failed to allocate memory in device");
    return false;
  }

  if vk_fail(vk.bind_image_memory(device, image.vk_image, image.vk_image_memory, 0)) {
    log.error("Error: failed to bind memory to device");
    return false;
  }

  return true;
}


// ImageViewCreateInfo :: struct {
//     sType : StructureType,
//     pNext : rawptr,
//     flags : ImageViewCreateFlags,
//     image : Image,
//     viewType : ImageViewType,
//     format : Format,
//     components : ComponentMapping,
//     subresourceRange : ImageSubresourceRange,
// };

image_create_vk_image_view :: proc(image: ^Image,
                                   device: vk.Device,
                                   format: vk.Format,
                                   aspectMask: vk.ImageAspectFlagBits) -> bool {
  view_info := vk.ImageViewCreateInfo {
    sType = vk.StructureType.ImageViewCreateInfo,
    image = image.vk_image,
    viewType = vk.ImageViewType._2D,
    format = format,
    subresourceRange = {
      aspectMask = u32(aspectMask),
      baseMipLevel = 0,
      levelCount = 1,
      baseArrayLayer = 0,
      layerCount = 1,
    },
  };

  imageView: vk.ImageView;
  if vk.create_image_view(ctx.device, &viewInfo, nil, &imageView) == vk.Result.Success {
    return imageView, true;
  }

  log.error("Error: failed to create image view");
  return nil, false;
}
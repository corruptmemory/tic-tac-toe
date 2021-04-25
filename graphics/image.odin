package graphics

import vk "shared:vulkan"
import "core:strings"
import "core:mem"

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
                              image_view_type: vk.ImageViewType,
                              flags: vk.ImageCreateFlags) {
imageInfo := vk.ImageCreateInfo{
    sType = vk.StructureType.ImageCreateInfo,
    imageType = vk.ImageType._2D,
    extent = image_get_extent(image),
    mipLevels = 1,
    arrayLayers = 1,
    format = format,
    tiling = tiling,
    initialLayout = vk.ImageLayout.Undefined,
    usage = u32(usage),
    sharingMode = vk.SharingMode.Exclusive,
    samples = vk.SampleCountFlagBits._1,
    flags = flags,
  };
}
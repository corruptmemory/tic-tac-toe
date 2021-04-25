package graphics

import vk "shared:vulkan"
import "core:log"

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
                                   aspectMask: vk.ImageAspectFlagBits,
                                   view_type: vk.ImageViewType = vk.ImageViewType._2D) -> (vk.ImageView, bool) {
  view_info := vk.ImageViewCreateInfo {
    sType = vk.StructureType.ImageViewCreateInfo,
    image = image.vk_image,
    viewType = view_type,
    format = format,
    subresourceRange = {
      aspectMask = u32(aspectMask),
      baseMipLevel = 0,
      levelCount = 1,
      baseArrayLayer = 0,
      layerCount = 1,
    },
  };

  image_view: vk.ImageView;
  if vk_success(vk.create_image_view(image.device, &view_info, nil, &image_view)) {
    return image_view, true;
  }

  log.error("Error: failed to create image view");
  return nil, false;
}
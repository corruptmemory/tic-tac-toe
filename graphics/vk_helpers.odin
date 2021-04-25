package graphics

import vk "shared:vulkan"
import "core:log"

vk_fail :: proc(r: vk.Result, location := #caller_location) -> bool {
  if r == vk.Result.Success {
    return false;
  }
  log.error("Error: expected vk.Result.Success, got: %v", r, location = location);
  return true;
}

vk_find_memory_type :: proc(physical_device: vk.PhysicalDevice,
                            type_filter:u32,
                            properties: vk.MemoryPropertyFlags) -> (u32, bool) {
  mem_properties := vk.PhysicalDeviceMemoryProperties{};
  vk.get_physical_device_memory_properties(physical_device, &mem_properties);

  for i : u32 = 0; i < mem_properties.memoryTypeCount; i += 1 {
    if (type_filter & (1 << i)) != 0 && (mem_properties.memoryTypes[i].propertyFlags & properties) == properties {
      return i, true;
    }
  }

  return 0, false;
}
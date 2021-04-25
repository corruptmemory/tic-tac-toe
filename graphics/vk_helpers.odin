package graphics

import vk "shared:vulkan"
import "core:log"

vk_fail :: proc(r: vk.Result, location := #caller_location) -> bool {
  if r == vk.Result.Success do return false;
  log.errorf(fmt_str = "Error: expected vk.Result.Success, got: %v", args = {r}, location = location);
  return true;
}

vk_success :: proc(r: vk.Result, location := #caller_location) -> bool {
  if r == vk.Result.Success do return true;
  log.errorf(fmt_str = "Error: expected vk.Result.Success, got: %v", args = {r}, location = location);
  return false;
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

vk_create_buffer :: proc(device: vk.Device,
                         physical_device: vk.PhysicalDevice,
                         size: vk.DeviceSize,
                         usage: vk.BufferUsageFlagBits,
                         properties: vk.MemoryPropertyFlagBits,
                         buffer: ^vk.Buffer,
                         buffer_memory: ^vk.DeviceMemory,
                         sharing_mode: vk.SharingMode = vk.SharingMode.Exclusive) -> bool {
  buffer_info := vk.BufferCreateInfo {
    sType = vk.StructureType.BufferCreateInfo,
    size = u64(size),
    usage = u32(usage),
    sharingMode = sharing_mode,
  };

  if vk_fail(vk.create_buffer(device, &buffer_info, nil, buffer)) {
    log.error("Error: failed to create buffer");
    return false;
  }

  mem_requirements: vk.MemoryRequirements;
  vk.get_buffer_memory_requirements(device, buffer^, &mem_requirements);

  memory_type_index, ok := vk_find_memory_type(physical_device, mem_requirements.memoryTypeBits, u32(properties));
  if !ok {
    log.error("Error: failed to find desired memory type");
    return false;
  }

  alloc_info := vk.MemoryAllocateInfo{
    sType = vk.StructureType.MemoryAllocateInfo,
    allocationSize = mem_requirements.size,
    memoryTypeIndex = memory_type_index,
  };

  if vk_fail(vk.allocate_memory(device, &alloc_info, nil, buffer_memory)) {
    log.error("Error: failed to allocate memory");
    return false;
  }

  if vk_fail(vk.bind_buffer_memory(device, buffer^, buffer_memory^, 0)) {
    log.error("Error: failed to bind");
    return false;
  }
  return true;
}

vk_begin_single_time_commands :: proc(device: vk.Device,
                                      command_pool: vk.CommandPool) -> vk.CommandBuffer {
  alloc_info := vk.CommandBufferAllocateInfo {
    sType = vk.StructureType.CommandBufferAllocateInfo,
    level = vk.CommandBufferLevel.Primary,
    commandPool = command_pool,
    commandBufferCount = 1,
  };

  command_buffer := vk.CommandBuffer{};
  vk.allocate_command_buffers(device, &alloc_info, &command_buffer);

  begin_info := vk.CommandBufferBeginInfo {
    sType = vk.StructureType.CommandBufferBeginInfo,
    flags = u32(vk.CommandBufferUsageFlagBits.OneTimeSubmit),
  };

  vk.begin_command_buffer(command_buffer, &begin_info);

  return command_buffer;
}

vk_end_single_time_commands :: proc(device: vk.Device,
                                    command_pool: vk.CommandPool,
                                    queue: vk.Queue,
                                    command_buffer: ^vk.CommandBuffer) {
  vk.end_command_buffer(command_buffer^);

  submit_info := vk.SubmitInfo{
    sType = vk.StructureType.SubmitInfo,
    commandBufferCount = 1,
    pCommandBuffers = command_buffer,
  };

  vk.queue_submit(queue, 1, &submit_info, nil);
  vk.queue_wait_idle(queue);

  vk.free_command_buffers(device, command_pool, 1, command_buffer);
}
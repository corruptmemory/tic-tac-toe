package graphics

import "core:mem"
import rt "core:runtime"
// import "core:math/bits"
import "core:os"
import vk "shared:vulkan"
import lin "core:math/linalg"
import "core:log"
import "core:strings"
import bc "../build_config"
// import stbi "shared:stb/stbi"
import "../assets"

max_frames_in_flight :: 2;

Swapchain_Buffer :: struct {
  image: vk.Image,
  view: vk.ImageView,
};

Texture :: struct {
  image: ^u8,
  sampler: vk.Sampler,
};

Vertex :: struct {
  pos: lin.Vector3f32,
  normal: lin.Vector3f32,
  color: lin.Vector3f32,
  uv: lin.Vector2f32,
  joint0: lin.Vector4f32,
  weight0: lin.Vector3f32,
};

Uniform_Buffer_Object :: struct {
    proj: lin.Matrix4f32,
    view: lin.Matrix4f32,
    light_pos: lin.Vector4f32,
    loc_speed: f32,
    glob_speed: f32,
};

Instance_Data :: struct {
  pos: lin.Vector3f32,
  rot: lin.Vector3f32,
  scale: f32,
  tex_index: u32,
};

ThreeD_Asset :: struct {
  vertices: []Vertex,
  indices: []u32,
  vertex_buffer: vk.Buffer,
  vertex_buffer_memory: vk.DeviceMemory,
  index_buffer: vk.Buffer,
  index_buffer_memory: vk.DeviceMemory,
};

Graphics_Context :: struct {
  instance : vk.Instance,
  device: vk.Device,
  physicalDevice: vk.PhysicalDevice,
  surface: vk.SurfaceKHR,
  graphicsFamily: u32,
  presentFamily: u32,
  graphicsQueue: vk.Queue,
  presentQueue: vk.Queue,
  swapChain: vk.SwapchainKHR,
  swapChainImages: []vk.Image,
  swapChainImageFormat: vk.Format,
  swapChainExtent: vk.Extent2D,
  swapChainImageViews: []vk.ImageView,
  swapChainFramebuffers: []vk.Framebuffer,
  capabilities: vk.SurfaceCapabilitiesKHR,
  formats: []vk.SurfaceFormatKHR,
  presentModes: []vk.PresentModeKHR,
  pipeline_layout: vk.PipelineLayout,
  renderPass: vk.RenderPass,
  commandPool: vk.CommandPool,
  commandBuffers: []vk.CommandBuffer,
  background_pipeline: vk.Pipeline,
  piece_pipeline: vk.Pipeline,
  board_pipeline: vk.Pipeline,
  imageAvailableSemaphores: []vk.Semaphore,
  renderFinishedSemaphores: []vk.Semaphore,
  inFlightFences: []vk.Fence,
  imagesInFlight: []vk.Fence,
  descriptor_set_layout: vk.DescriptorSetLayout,
  uniform_buffers: []vk.Buffer,
  uniform_buffers_memory: []vk.DeviceMemory,
  descriptorPool: vk.DescriptorPool,
  descriptorSets: []vk.DescriptorSet,
  currentFrame: int,
  framebufferResized: bool,
  texture_image: vk.Image,
  texture_image_memory: vk.DeviceMemory,
  texture_image_view: vk.ImageView,
  texture_sampler: vk.Sampler,
  window: WINDOW_TYPE,
  width: u32,
  height: u32,
  depthImage: vk.Image,
  depthImageMemory: vk.DeviceMemory,
  depthImageView: vk.ImageView,
  piece: ThreeD_Asset,
  board: ThreeD_Asset,
}

Shader_Info :: struct {
  vertex_info: vk.PipelineShaderStageCreateInfo,
  fragment_info: vk.PipelineShaderStageCreateInfo,
  bindings: []vk.VertexInputBindingDescription,
  attributes: []vk.VertexInputAttributeDescription,
}

init_shader_info :: proc(info: ^Shader_Info,
                         device: vk.Device,
                         vertex_file: string,
                         fragment_file: string,
                         bindings: []vk.VertexInputBindingDescription,
                         attributes: []vk.VertexInputAttributeDescription) -> bool {
  ok: bool;
  info.vertex_info, ok = load_shader(device, vertex_file, vk.ShaderStageFlagBits.Vertex);
  if !ok do return false;
  info.fragment_info, ok = load_shader(device, fragment_file, vk.ShaderStageFlagBits.Fragment);
  if !ok {
    vk.destroy_shader_module(device, info.vertex_info.module, nil);
    return false;
  }
  info.bindings = bindings;
  info.attributes = attributes;
  return true;
}


delete_shader_info :: proc(device: vk.Device, info: ^Shader_Info) {
  vk.destroy_shader_module(device, info.vertex_info.module, nil);
  info.vertex_info.module = nil;
  vk.destroy_shader_module(device, info.fragment_info.module, nil);
  info.fragment_info.module = nil;
}


graphics_init :: proc(ctx: ^Graphics_Context,
                      application_name: string = "tic-tac-toe") -> bool {

  if !graphics_create_vulkan_instance(ctx, application_name) do return false;
  if !graphics_pick_physical_device(ctx) do return false;
  if !graphics_check_device_extension_support(ctx) do return false;
  return true;
}


graphics_check_device_extension_support :: proc(ctx: ^Graphics_Context) -> bool {
  context.allocator = context.temp_allocator;
  extension_count: u32;
  vk.enumerate_device_extension_properties(ctx.physicalDevice, nil, &extension_count, nil);

  available_extensions := make([]vk.ExtensionProperties,extension_count);
  vk.enumerate_device_extension_properties(ctx.physicalDevice, nil, &extension_count, mem.raw_slice_data(available_extensions));

  expected := make(map[string]bool);
  defer delete(expected);
  for x, _ in device_extensions {
    expected[string(x)] = false;
  }

  for _, i in available_extensions {
    x := available_extensions[i];
    en := string(transmute(cstring)(&x.extensionName));
    delete_key(&expected, en);
  }

  if len(expected) == 0 do return true;

  log.error("Error: unable to find expected device extensions");
  return false;
}


graphics_update_uniform_buffer :: proc(ctx: ^Graphics_Context, current_image: u32) {
  ubo := Uniform_Buffer_Object {
    view = lin.matrix4_look_at(lin.Vector3f32{2,2,2},lin.Vector3f32{0,0,0},lin.VECTOR3F32_Z_AXIS),
    proj = lin.matrix4_perspective_f32(lin.radians(f32(45)),f32(ctx.swapChainExtent.width)/f32(ctx.swapChainExtent.height),0.1,10),
    light_pos  = lin.Vector4f32{0.0, -5.0, 0.0, 1.0},
  };

  ubo.proj[1][1] *= -1;

  data: rawptr;
  vk.map_memory(ctx.device,ctx.uniform_buffers_memory[current_image],0,size_of(ubo),0,&data);
  rt.mem_copy_non_overlapping(data,&ubo,size_of(ubo));
  vk.unmap_memory(ctx.device,ctx.uniform_buffers_memory[current_image]);
}


graphics_find_supported_format :: proc(ctx:^Graphics_Context, candidates: []vk.Format, tiling: vk.ImageTiling, features: vk.FormatFeatureFlags) -> (vk.Format, bool) {
  for format in candidates {
    props: vk.FormatProperties;
    vk.get_physical_device_format_properties(ctx.physicalDevice, format, &props);
      if tiling == vk.ImageTiling.Linear && (props.linearTilingFeatures & features) == features {
        return format, true;
      } else if tiling == vk.ImageTiling.Optimal && (props.optimalTilingFeatures & features) == features {
        return format, true;
      }
  }

  log.error("Error: failed to find usable tiling format");

  return vk.Format.Undefined, false;
}


graphics_find_depth_format :: proc(ctx: ^Graphics_Context) -> (vk.Format, bool) {
  return graphics_find_supported_format(ctx,
                               {vk.Format.D32Sfloat, vk.Format.D32SfloatS8Uint, vk.Format.D24UnormS8Uint},
                               vk.ImageTiling.Optimal,
                               u32(vk.FormatFeatureFlagBits.DepthStencilAttachment));
}


graphics_create_depth_resources :: proc(ctx: ^Graphics_Context) -> bool {
  depth_format: vk.Format;
  ok: bool;
  if depth_format, ok = graphics_find_depth_format(ctx); !ok {
    log.error("Error: could not find usable depth format");
    return false;
  }
  graphics_create_image(ctx, ctx.swapChainExtent.width, ctx.swapChainExtent.height, depth_format, vk.ImageTiling.Optimal, vk.ImageUsageFlagBits.DepthStencilAttachment, vk.MemoryPropertyFlagBits.DeviceLocal, &ctx.depthImage, &ctx.depthImageMemory);
  ctx.depthImageView, ok = graphics_create_image_view(ctx, ctx.depthImage, depth_format, vk.ImageAspectFlagBits.Depth);
  return true;
}


graphics_init_post_window :: proc(ctx: ^Graphics_Context,
                                  width: u32,
                                  height: u32) -> bool
{
  ctx.width = width;
  ctx.height = height;

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
  if !graphics_create_depth_resources(ctx) do return false;
  if !graphics_create_framebuffers(ctx) do return false;
  // if !graphics_create_texture_image(ctx) do return false;
  if !graphics_create_texture_image_view(ctx) do return false;
  if !graphics_create_texture_sampler(ctx) do return false;
  if !graphics_create_uniform_buffers(ctx) do return false;
  if !graphics_create_descriptor_pool(ctx) do return false;
  if !graphics_create_descriptor_sets(ctx) do return false;
  if !graphics_create_sync_objects(ctx) do return false;

  return true;
}


graphics_cleanup_swap_chain :: proc(ctx: ^Graphics_Context) -> bool {
  vk.destroy_image_view(ctx.device, ctx.depthImageView, nil);
  vk.destroy_image(ctx.device, ctx.depthImage, nil);
  vk.free_memory(ctx.device, ctx.depthImageMemory, nil);
  for framebuffer, _ in ctx.swapChainFramebuffers {
    vk.destroy_framebuffer(ctx.device, framebuffer, nil);
  }
  delete(ctx.swapChainFramebuffers);
  ctx.swapChainFramebuffers = nil;

  vk.free_command_buffers(ctx.device, ctx.commandPool, u32(len(ctx.commandBuffers)), mem.raw_slice_data(ctx.commandBuffers));
  delete(ctx.commandBuffers);
  ctx.commandBuffers = nil;

  vk.destroy_pipeline(ctx.device, ctx.piece_pipeline, nil);
  vk.destroy_pipeline(ctx.device, ctx.board_pipeline, nil);
  vk.destroy_pipeline(ctx.device, ctx.background_pipeline, nil);

  vk.destroy_pipeline_layout(ctx.device, ctx.pipeline_layout, nil);
  vk.destroy_render_pass(ctx.device, ctx.renderPass, nil);

  for imageView, _ in ctx.swapChainImageViews {
    vk.destroy_image_view(ctx.device, imageView, nil);
  }
  delete(ctx.swapChainImageViews);
  ctx.swapChainImageViews = nil;

  vk.destroy_swapchain_khr(ctx.device, ctx.swapChain, nil);

  for i := 0; i < len(ctx.swapChainImages); i += 1 {
    vk.destroy_buffer(ctx.device, ctx.uniform_buffers[i], nil);
    vk.free_memory(ctx.device, ctx.uniform_buffers_memory[i], nil);
  }
  delete(ctx.uniform_buffers);
  delete(ctx.uniform_buffers_memory);
  ctx.uniform_buffers = nil;
  ctx.uniform_buffers_memory = nil;

  vk.destroy_descriptor_pool(ctx.device, ctx.descriptorPool, nil);

  return true;
}


graphics_recreate_swap_chain :: proc(ctx: ^Graphics_Context) -> bool {
  if ctx.width == 0 || ctx.height == 0 do return true;

  vk.device_wait_idle(ctx.device);

  if !graphics_cleanup_swap_chain(ctx) do return false;
  if !graphics_create_swap_chain(ctx) do return false;
  if !graphics_create_image_views(ctx) do return false;
  if !graphics_create_render_pass(ctx) do return false;
  if !graphics_create_graphics_pipeline(ctx) do return false;
  if !graphics_create_depth_resources(ctx) do return false;
  if !graphics_create_framebuffers(ctx) do return false;
  if !graphics_create_uniform_buffers(ctx) do return false;
  if !graphics_create_descriptor_pool(ctx) do return false;
  if !graphics_create_descriptor_sets(ctx) do return false;
  return true;
}


graphics_create_sync_objects :: proc(ctx: ^Graphics_Context) -> bool {
  ctx.imageAvailableSemaphores = make([]vk.Semaphore,max_frames_in_flight);
  ctx.renderFinishedSemaphores = make([]vk.Semaphore,max_frames_in_flight);
  ctx.inFlightFences = make([]vk.Fence,max_frames_in_flight);
  ctx.imagesInFlight = make([]vk.Fence,len(ctx.swapChainImages));

  semaphoreInfo := vk.SemaphoreCreateInfo{};
  semaphoreInfo.sType = vk.StructureType.SemaphoreCreateInfo;

  fenceInfo := vk.FenceCreateInfo{};
  fenceInfo.sType = vk.StructureType.FenceCreateInfo;
  fenceInfo.flags = u32(vk.FenceCreateFlagBits.Signaled);


  for i := 0; i < max_frames_in_flight; i += 1 {
    if (vk.create_semaphore(ctx.device, &semaphoreInfo, nil, &ctx.imageAvailableSemaphores[i]) != vk.Result.Success ||
      vk.create_semaphore(ctx.device, &semaphoreInfo, nil, &ctx.renderFinishedSemaphores[i]) != vk.Result.Success ||
      vk.create_fence(ctx.device, &fenceInfo, nil, &ctx.inFlightFences[i]) != vk.Result.Success) {
      log.error("Error: failed to create sync object");
      return false;
    }
  }
  return true;
}


graphics_create_descriptor_sets :: proc(ctx: ^Graphics_Context) -> bool {
  layouts := make([]vk.DescriptorSetLayout,len(ctx.swapChainImages));
  for _, i in layouts {
      layouts[i] = ctx.descriptor_set_layout;
  }
  allocInfo := vk.DescriptorSetAllocateInfo{
      sType = vk.StructureType.DescriptorSetAllocateInfo,
      descriptorPool = ctx.descriptorPool,
      descriptorSetCount = u32(len(ctx.swapChainImages)),
      pSetLayouts = mem.raw_slice_data(layouts),
  };

  ctx.descriptorSets = make([]vk.DescriptorSet,len(ctx.swapChainImages));

  if vk.allocate_descriptor_sets(ctx.device,&allocInfo,mem.raw_slice_data(ctx.descriptorSets)) != vk.Result.Success {
    log.error("Error: failed to allocate descriptor sets");
    return false;
  }

  for _, i in ctx.swapChainImages {
    bufferInfo := vk.DescriptorBufferInfo{
      buffer = ctx.uniform_buffers[i],
      offset = 0,
      range = size_of(Uniform_Buffer_Object),
    };

    imageInfo := vk.DescriptorImageInfo {
      imageLayout = vk.ImageLayout.ShaderReadOnlyOptimal,
      imageView = ctx.texture_image_view,
      sampler = ctx.texture_sampler,
    };

    descriptorWrite := []vk.WriteDescriptorSet {
      {
        sType = vk.StructureType.WriteDescriptorSet,
        dstSet = ctx.descriptorSets[i],
        dstBinding = 0,
        dstArrayElement = 0,
        descriptorType = vk.DescriptorType.UniformBuffer,
        descriptorCount = 1,
        pBufferInfo = &bufferInfo,
      },
      {
        sType = vk.StructureType.WriteDescriptorSet,
        dstSet = ctx.descriptorSets[i],
        dstBinding = 1,
        dstArrayElement = 0,
        descriptorType = vk.DescriptorType.CombinedImageSampler,
        descriptorCount = 1,
        pImageInfo = &imageInfo,
      },
    };
    vk.update_descriptor_sets(ctx.device, u32(len(descriptorWrite)), mem.raw_slice_data(descriptorWrite), 0, nil);
  }

  return true;
}


graphics_create_descriptor_pool :: proc(ctx: ^Graphics_Context) -> bool {
  poolSize := []vk.DescriptorPoolSize {
    {
      type = vk.DescriptorType.UniformBuffer,
      descriptorCount = u32(len(ctx.swapChainImages)),
    },
    {
      type = vk.DescriptorType.CombinedImageSampler,
      descriptorCount = u32(len(ctx.swapChainImages)),
    },
  };

  poolInfo := vk.DescriptorPoolCreateInfo {
    sType = vk.StructureType.DescriptorPoolCreateInfo,
    poolSizeCount = u32(len(poolSize)),
    pPoolSizes = mem.raw_slice_data(poolSize),
    maxSets = u32(len(ctx.swapChainImages)),
  };

  if vk.create_descriptor_pool(ctx.device, &poolInfo, nil, &ctx.descriptorPool) != vk.Result.Success {
    log.error("Error: failed to create descriptor pool");
    return false;
  }

  return true;
}


graphics_create_uniform_buffers :: proc(ctx: ^Graphics_Context) -> bool {
    bufferSize := vk.DeviceSize(size_of(Uniform_Buffer_Object));

    ctx.uniform_buffers = make([]vk.Buffer,len(ctx.swapChainImages));
    ctx.uniform_buffers_memory = make([]vk.DeviceMemory,len(ctx.swapChainImages));

    for _, i in ctx.swapChainImages {
        if !graphics_create_buffer(ctx, bufferSize, vk.BufferUsageFlagBits.UniformBuffer, vk.MemoryPropertyFlagBits.HostVisible | vk.MemoryPropertyFlagBits.HostCoherent, &ctx.uniform_buffers[i], &ctx.uniform_buffers_memory[i]) {
          log.error("Error: failed to create needed buffer for the uniform buffer construction");
          return false;
        }
    }
    return true;
}


graphics_copy_buffer :: proc(ctx: ^Graphics_Context, srcBuffer: vk.Buffer, dstBuffer: vk.Buffer, size: vk.DeviceSize) {
  allocInfo := vk.CommandBufferAllocateInfo{
    sType = vk.StructureType.CommandBufferAllocateInfo,
    level = vk.CommandBufferLevel.Primary,
    commandPool = ctx.commandPool,
    commandBufferCount = 1,
  };

  commandBuffer: vk.CommandBuffer;
  vk.allocate_command_buffers(ctx.device, &allocInfo, &commandBuffer);

  beginInfo := vk.CommandBufferBeginInfo{
    sType = vk.StructureType.CommandBufferBeginInfo,
    flags = u32(vk.CommandBufferUsageFlagBits.OneTimeSubmit),
  };

  vk.begin_command_buffer(commandBuffer, &beginInfo);

  copyRegion := vk.BufferCopy{
    size = size,
  };
  vk.cmd_copy_buffer(commandBuffer, srcBuffer, dstBuffer, 1, &copyRegion);

  vk.end_command_buffer(commandBuffer);

  submitInfo := vk.SubmitInfo{
    sType = vk.StructureType.SubmitInfo,
    commandBufferCount = 1,
    pCommandBuffers = &commandBuffer,
  };

  vk.queue_submit(ctx.graphicsQueue, 1, &submitInfo, nil);
  vk.queue_wait_idle(ctx.graphicsQueue);

  vk.free_command_buffers(ctx.device, ctx.commandPool, 1, &commandBuffer);
}


graphics_create_texture_sampler :: proc(ctx: ^Graphics_Context) -> bool {
  properties: vk.PhysicalDeviceProperties;
  vk.get_physical_device_properties(ctx.physicalDevice, &properties);

  samplerInfo := vk.SamplerCreateInfo{
    sType = vk.StructureType.SamplerCreateInfo,
    magFilter = vk.Filter.Linear,
    minFilter = vk.Filter.Linear,
    addressModeU = vk.SamplerAddressMode.Repeat,
    addressModeV = vk.SamplerAddressMode.Repeat,
    addressModeW = vk.SamplerAddressMode.Repeat,
    anisotropyEnable = vk.TRUE,
    maxAnisotropy = properties.limits.maxSamplerAnisotropy,
    borderColor = vk.BorderColor.IntOpaqueBlack,
    unnormalizedCoordinates = vk.FALSE,
    compareEnable = vk.FALSE,
    compareOp = vk.CompareOp.Always,
    mipmapMode = vk.SamplerMipmapMode.Linear,
    mipLodBias = 0.0,
    minLod = 0.0,
    maxLod = 0.0,
  };

  if vk.create_sampler(ctx.device, &samplerInfo, nil, &ctx.texture_sampler) != vk.Result.Success {
    log.error("Error: failed to create texture sampler!");
    return false;
  }
  return true;
}


graphics_create_texture_image_view :: proc(ctx: ^Graphics_Context) -> bool {
  textureImageView, result := graphics_create_image_view(ctx, ctx.texture_image, vk.Format.R8G8B8A8Srgb, vk.ImageAspectFlagBits.Color);
  ctx.texture_image_view = textureImageView;
  return result;
}


graphics_find_memory_type :: proc(ctx:^Graphics_Context, typeFilter:u32, properties: vk.MemoryPropertyFlags) -> (u32, bool) {
  memProperties := vk.PhysicalDeviceMemoryProperties{};
  vk.get_physical_device_memory_properties(ctx.physicalDevice, &memProperties);

  for i : u32 = 0; i < memProperties.memoryTypeCount; i += 1 {
    if (typeFilter & (1 << i)) != 0 && (memProperties.memoryTypes[i].propertyFlags & properties) == properties {
      return i, true;
    }
  }

  return 0, false;
}


graphics_create_buffer :: proc(ctx: ^Graphics_Context, size: vk.DeviceSize, usage: vk.BufferUsageFlagBits, properties: vk.MemoryPropertyFlagBits, buffer: ^vk.Buffer, bufferMemory: ^vk.DeviceMemory) -> bool {
  bufferInfo := vk.BufferCreateInfo {
    sType = vk.StructureType.BufferCreateInfo,
    size = u64(size),
    usage = u32(usage),
    sharingMode = vk.SharingMode.Exclusive,
  };

  if (vk.create_buffer(ctx.device, &bufferInfo, nil, buffer) != vk.Result.Success) {
    log.error("Error: failed to create buffer");
    return false;
  }

  memRequirements: vk.MemoryRequirements;
  vk.get_buffer_memory_requirements(ctx.device, buffer^, &memRequirements);

  memoryTypeIndex, ok := graphics_find_memory_type(ctx, memRequirements.memoryTypeBits, u32(properties));

  if !ok {
    log.error("Error: failed to find desired memory type");
    return false;
  }

  allocInfo := vk.MemoryAllocateInfo{
    sType = vk.StructureType.MemoryAllocateInfo,
    allocationSize = memRequirements.size,
    memoryTypeIndex = memoryTypeIndex,
  };

  if vk.allocate_memory(ctx.device, &allocInfo, nil, bufferMemory) != vk.Result.Success {
    log.error("Error: failed to allocate memory");
    return false;
  }

  vk.bind_buffer_memory(ctx.device, buffer^, bufferMemory^, 0);
  return true;
}


graphics_create_image :: proc(ctx: ^Graphics_Context, width, height: u32, format: vk.Format, tiling: vk.ImageTiling, usage: vk.ImageUsageFlagBits, properties: vk.MemoryPropertyFlagBits, image: ^vk.Image, imageMemory: ^vk.DeviceMemory) -> bool {
 imageInfo := vk.ImageCreateInfo{
    sType = vk.StructureType.ImageCreateInfo,
    imageType = vk.ImageType._2D,
    extent = {
      width = width,
      height = height,
      depth = 1,
    },
    mipLevels = 1,
    arrayLayers = 1,
    format = format,
    tiling = tiling,
    initialLayout = vk.ImageLayout.Undefined,
    usage = u32(usage),
    sharingMode = vk.SharingMode.Exclusive,
    samples = vk.SampleCountFlagBits._1,
    flags = 0,
  };

  if vk.create_image(ctx.device, &imageInfo, nil, image) != vk.Result.Success {
    log.error("Failed to create image for the texture map");
    return false;
  }

  memRequirements: vk.MemoryRequirements;
  vk.get_image_memory_requirements(ctx.device,image^,&memRequirements);

  mt, ok := graphics_find_memory_type(ctx, memRequirements.memoryTypeBits, u32(properties));
  if !ok {
    log.error("Error: failed to find memory");
    return false;
  }

  allocInfo := vk.MemoryAllocateInfo {
    sType = vk.StructureType.MemoryAllocateInfo,
    allocationSize = memRequirements.size,
    memoryTypeIndex = mt,
  };

  if vk.allocate_memory(ctx.device, &allocInfo, nil, imageMemory) != vk.Result.Success {
    log.error("Error: failed to allocate memory in device");
    return false;
  }

  vk.bind_image_memory(ctx.device, image^, imageMemory^, 0);

  return true;
}


graphics_begin_single_time_commands :: proc(ctx: ^Graphics_Context) -> vk.CommandBuffer {
  allocInfo := vk.CommandBufferAllocateInfo{
    sType = vk.StructureType.CommandBufferAllocateInfo,
    level = vk.CommandBufferLevel.Primary,
    commandPool = ctx.commandPool,
    commandBufferCount = 1,
  };

  commandBuffer := vk.CommandBuffer{};
  vk.allocate_command_buffers(ctx.device, &allocInfo, &commandBuffer);

  beginInfo := vk.CommandBufferBeginInfo{
    sType = vk.StructureType.CommandBufferBeginInfo,
    flags = u32(vk.CommandBufferUsageFlagBits.OneTimeSubmit),
  };

  vk.begin_command_buffer(commandBuffer, &beginInfo);

  return commandBuffer;
}

graphics_end_single_time_commands :: proc(ctx: ^Graphics_Context, commandBuffer: ^vk.CommandBuffer) {
  vk.end_command_buffer(commandBuffer^);

  submitInfo := vk.SubmitInfo{
    sType = vk.StructureType.SubmitInfo,
    commandBufferCount = 1,
    pCommandBuffers = commandBuffer,
  };

  vk.queue_submit(ctx.graphicsQueue, 1, &submitInfo, nil);
  vk.queue_wait_idle(ctx.graphicsQueue);

  vk.free_command_buffers(ctx.device, ctx.commandPool, 1, commandBuffer);
}

graphics_copy_buffer_to_image :: proc(ctx: ^Graphics_Context, buffer: vk.Buffer, image: vk.Image, width, height: u32) {
  commandBuffer := graphics_begin_single_time_commands(ctx);

  region := vk.BufferImageCopy{
    bufferOffset = 0,
    bufferRowLength = 0,
    bufferImageHeight = 0,
    imageSubresource = {
      aspectMask =u32(vk.ImageAspectFlagBits.Color),
      mipLevel = 0,
      baseArrayLayer = 0,
      layerCount = 1,
    },
    imageOffset = {0, 0, 0},
    imageExtent = {width, height, 1},
  };

  vk.cmd_copy_buffer_to_image(commandBuffer, buffer, image, vk.ImageLayout.TransferDstOptimal, 1, &region);

  graphics_end_single_time_commands(ctx, &commandBuffer);
}


graphics_transition_image_layout :: proc(ctx: ^Graphics_Context, image: vk.Image, format: vk.Format, oldLayout: vk.ImageLayout, newLayout: vk.ImageLayout) -> bool {
  commandBuffer := graphics_begin_single_time_commands(ctx);

  ufi : i32 = vk.QUEUE_FAMILY_IGNORED;

  barrier := vk.ImageMemoryBarrier {
    sType = vk.StructureType.ImageMemoryBarrier,
    oldLayout = oldLayout,
    newLayout = newLayout,
    srcQueueFamilyIndex = transmute(u32)(ufi),
    dstQueueFamilyIndex = transmute(u32)(ufi),
    image = image,
    subresourceRange = vk.ImageSubresourceRange{
      aspectMask = u32(vk.ImageAspectFlagBits.Color),
      baseMipLevel = 0,
      levelCount = 1,
      baseArrayLayer = 0,
      layerCount = 1,
    },
  };

  sourceStage: vk.PipelineStageFlags;
  destinationStage: vk.PipelineStageFlags;

  if oldLayout == vk.ImageLayout.Undefined && newLayout == vk.ImageLayout.TransferDstOptimal {
    barrier.srcAccessMask = 0;
    barrier.dstAccessMask = u32(vk.AccessFlagBits.TransferWrite);
    sourceStage = u32(vk.PipelineStageFlagBits.TopOfPipe);
    destinationStage = u32(vk.PipelineStageFlagBits.Transfer);
  } else if oldLayout == vk.ImageLayout.TransferDstOptimal && newLayout == vk.ImageLayout.ShaderReadOnlyOptimal {
    barrier.srcAccessMask = u32(vk.AccessFlagBits.TransferWrite);
    barrier.dstAccessMask = u32(vk.AccessFlagBits.ShaderRead);
    sourceStage = u32(vk.PipelineStageFlagBits.Transfer);
    destinationStage = u32(vk.PipelineStageFlagBits.FragmentShader);
  } else if oldLayout == vk.ImageLayout.Undefined && newLayout == vk.ImageLayout.DepthStencilAttachmentOptimal {
    barrier.srcAccessMask = 0;
    barrier.dstAccessMask = u32(vk.AccessFlagBits.DepthStencilAttachmentRead | vk.AccessFlagBits.DepthStencilAttachmentWrite);
    sourceStage = u32(vk.PipelineStageFlagBits.TopOfPipe);
    destinationStage = u32(vk.PipelineStageFlagBits.EarlyFragmentTests);
  } else {
    log.error("Error: unsupported layout transition!");
    return false;
  }

  vk.cmd_pipeline_barrier(
    commandBuffer,
    sourceStage, destinationStage,
    0,
    0, nil,
    0, nil,
    1, &barrier
  );

  graphics_end_single_time_commands(ctx, &commandBuffer);

  return true;
}

graphics_load_geometry :: proc(ctx: ^Graphics_Context) -> bool {
  ac: assets.Asset_Catalog;
  assets.init_assets(&ac);
  ok := assets.load_3d_models(&ac, "/home/jim/projects/tic-tac-toe/blender/X.obj");
  if !ok {
    log.error("Error: failed to load piece geometry");
    return false;
  }
  // defer free_all(context.temp_allocator);

  for _, v in ac.models {
    vertices := make([dynamic]Vertex, 0, len(v.vertices));

    for v in v.vertices {
      append(&vertices, Vertex {
          pos = v.pos,
          color = v.color,
          uv = v.texture_coord,
      });
    }

    ctx.piece.vertices = vertices[:];
    ctx.piece.indices = v.indices[:];
  }

  ok = assets.load_3d_models(&ac, "/home/jim/projects/tic-tac-toe/blender/board.obj");
  if !ok {
    log.error("Error: failed to load board geometry");
    return false;
  }
  // defer free_all(context.temp_allocator);

  for _, v in ac.models {
    vertices := make([dynamic]Vertex, 0, len(v.vertices));

    for v in v.vertices {
      append(&vertices, Vertex {
          pos = v.pos,
          color = v.color,
          uv = v.texture_coord,
      });
    }

    ctx.board.vertices = vertices[:];
    ctx.board.indices = v.indices[:];
  }

  return true;
}


graphics_create_vertex_buffer :: proc(ctx: ^Graphics_Context, asset: ^ThreeD_Asset) -> bool {
  bufferSize : vk.DeviceSize = u64(size_of(asset.vertices[0]) * len(asset.vertices));

  stagingBuffer: vk.Buffer;
  stagingBufferMemory: vk.DeviceMemory;
  if !graphics_create_buffer(ctx,bufferSize,vk.BufferUsageFlagBits.TransferSrc,vk.MemoryPropertyFlagBits.HostVisible | vk.MemoryPropertyFlagBits.HostCoherent,&stagingBuffer,&stagingBufferMemory) {
    log.error("Error: failed to create host staging buffer");
    return false;
  }

  data: rawptr;
  vk.map_memory(ctx.device, stagingBufferMemory, 0, bufferSize, 0, &data);
  rt.mem_copy_non_overlapping(data, mem.raw_slice_data(asset.vertices), int(bufferSize));
  vk.unmap_memory(ctx.device, stagingBufferMemory);

  if !graphics_create_buffer(ctx,bufferSize,vk.BufferUsageFlagBits.TransferDst | vk.BufferUsageFlagBits.VertexBuffer, vk.MemoryPropertyFlagBits.DeviceLocal,&asset.vertex_buffer,&asset.vertex_buffer_memory) {
    log.error("Error: failed to create device local buffer");
    return false;
  }

  graphics_copy_buffer(ctx,stagingBuffer,asset.vertex_buffer,bufferSize);

  vk.destroy_buffer(ctx.device,stagingBuffer,nil);
  vk.free_memory(ctx.device,stagingBufferMemory,nil);

  return true;
}


graphics_create_index_buffer :: proc(ctx: ^Graphics_Context, asset: ^ThreeD_Asset) -> bool {
  bufferSize : vk.DeviceSize = u64(size_of(asset.indices[0]) * len(asset.indices));

  stagingBuffer : vk.Buffer;
  stagingBufferMemory : vk.DeviceMemory;
  graphics_create_buffer(ctx, bufferSize, vk.BufferUsageFlagBits.TransferSrc, vk.MemoryPropertyFlagBits.HostVisible | vk.MemoryPropertyFlagBits.HostCoherent, &stagingBuffer, &stagingBufferMemory);

  data : rawptr;
  vk.map_memory(ctx.device, stagingBufferMemory, 0, bufferSize, 0, &data);
  rt.mem_copy_non_overlapping(data, mem.raw_slice_data(asset.indices), int(bufferSize));
  vk.unmap_memory(ctx.device, stagingBufferMemory);

  graphics_create_buffer(ctx,bufferSize, vk.BufferUsageFlagBits.TransferDst | vk.BufferUsageFlagBits.IndexBuffer, vk.MemoryPropertyFlagBits.DeviceLocal, &asset.index_buffer, &asset.index_buffer_memory);

  graphics_copy_buffer(ctx,stagingBuffer, asset.index_buffer, bufferSize);

  vk.destroy_buffer(ctx.device, stagingBuffer, nil);
  vk.free_memory(ctx.device, stagingBufferMemory, nil);

  return true;
}


graphics_create_command_buffers :: proc(ctx: ^Graphics_Context, asset: ^ThreeD_Asset, pipeline: vk.Pipeline) -> bool {
  ctx.commandBuffers = make([]vk.CommandBuffer,len(ctx.swapChainFramebuffers));

  allocInfo := vk.CommandBufferAllocateInfo{
    sType = vk.StructureType.CommandBufferAllocateInfo,
    commandPool = ctx.commandPool,
    level = vk.CommandBufferLevel.Primary,
    commandBufferCount = u32(len(ctx.commandBuffers)),
  };

  clear_color_value : vk.ClearColorValue;
  clear_color_value.float32 = {0.0, 0.0, 0.0, 1.0};
  clear_color : vk.ClearValue;
  clear_color.color = clear_color_value;
  clear_depth_stencil_value := vk.ClearDepthStencilValue{1.0, 0};
  clear_depth_stencil: vk.ClearValue;
  clear_depth_stencil.depthStencil = clear_depth_stencil_value;

  clear_values := []vk.ClearValue{
    clear_color,
    clear_depth_stencil,
  };

  if vk.allocate_command_buffers(ctx.device, &allocInfo, mem.raw_slice_data(ctx.commandBuffers)) != vk.Result.Success {
    log.error("Error: failed to allocate command buffers");
    return false;
  }

  for cb, i in ctx.commandBuffers {
    beginInfo := vk.CommandBufferBeginInfo{sType = vk.StructureType.CommandBufferBeginInfo};

    if vk.begin_command_buffer(cb, &beginInfo) != vk.Result.Success {
      log.error("Error: failed to begin command buffer");
      return false;
    }

    renderPassInfo := vk.RenderPassBeginInfo{
      sType = vk.StructureType.RenderPassBeginInfo,
      renderPass = ctx.renderPass,
      framebuffer = ctx.swapChainFramebuffers[i],
      renderArea = {
        offset = {0, 0},
        extent = ctx.swapChainExtent,
      },
    };

    renderPassInfo.clearValueCount = u32(len(clear_values));
    renderPassInfo.pClearValues = mem.raw_slice_data(clear_values);

    vk.cmd_begin_render_pass(cb, &renderPassInfo, vk.SubpassContents.Inline);

    vk.cmd_bind_pipeline(cb, vk.PipelineBindPoint.Graphics, pipeline);

    vertexBuffers := []vk.Buffer{asset.vertex_buffer};
    offsets := []vk.DeviceSize{0};
    vk.cmd_bind_vertex_buffers(ctx.commandBuffers[i], 0, 1, mem.raw_slice_data(vertexBuffers), mem.raw_slice_data(offsets));
    vk.cmd_bind_index_buffer(ctx.commandBuffers[i],asset.index_buffer,0,vk.IndexType.Uint32);
    vk.cmd_bind_descriptor_sets(ctx.commandBuffers[i], vk.PipelineBindPoint.Graphics, ctx.pipeline_layout, 0, 1, &ctx.descriptorSets[i], 0, nil);
    vk.cmd_draw_indexed(ctx.commandBuffers[i], u32(len(asset.indices)), 1, 0, 0, 0);

    vk.cmd_end_render_pass(cb);

    if vk.end_command_buffer(cb) != vk.Result.Success {
      log.error("Error: failed to end the command buffer");
      return false;
    }
  }
  return true;
}


graphics_create_command_pool :: proc(ctx: ^Graphics_Context) -> bool {
    poolInfo := vk.CommandPoolCreateInfo{
      sType = vk.StructureType.CommandPoolCreateInfo,
      queueFamilyIndex = ctx.graphicsFamily,
    };

    if vk.create_command_pool(ctx.device, &poolInfo, nil, &ctx.commandPool) != vk.Result.Success {
      log.error("Error: could not create command pool");
      return false;
    }
    return true;
}

graphics_create_render_pass :: proc(ctx: ^Graphics_Context) -> bool {
  colorAttachment := vk.AttachmentDescription{
    format = ctx.swapChainImageFormat,
    samples = vk.SampleCountFlagBits._1,
    loadOp = vk.AttachmentLoadOp.Clear,
    storeOp = vk.AttachmentStoreOp.Store,
    stencilLoadOp = vk.AttachmentLoadOp.DontCare,
    stencilStoreOp = vk.AttachmentStoreOp.DontCare,
    initialLayout = vk.ImageLayout.Undefined,
    finalLayout = vk.ImageLayout.PresentSrcKhr,
  };

  depth_format, ok := graphics_find_depth_format(ctx);
  if !ok {
    log.error("Error: Failed to find a usable depth format");
    return false;
  }

  depthAttachment := vk.AttachmentDescription{
    format = depth_format,
    samples = vk.SampleCountFlagBits._1,
    loadOp = vk.AttachmentLoadOp.Clear,
    storeOp = vk.AttachmentStoreOp.DontCare,
    stencilLoadOp = vk.AttachmentLoadOp.DontCare,
    stencilStoreOp = vk.AttachmentStoreOp.DontCare,
    initialLayout = vk.ImageLayout.Undefined,
    finalLayout = vk.ImageLayout.DepthStencilAttachmentOptimal,
  };

  colorAttachmentRef := vk.AttachmentReference{
    attachment = 0,
    layout = vk.ImageLayout.ColorAttachmentOptimal,
  };

  depth_attachment_ref := vk.AttachmentReference {
    attachment = 1,
    layout = vk.ImageLayout.DepthStencilAttachmentOptimal,
  };

  subpass := vk.SubpassDescription{
    pipelineBindPoint = vk.PipelineBindPoint.Graphics,
    colorAttachmentCount = 1,
    pColorAttachments = &colorAttachmentRef,
    pDepthStencilAttachment = &depth_attachment_ref,
  };

  se : i32 = vk.SUBPASS_EXTERNAL;

  dependency := vk.SubpassDependency {
    srcSubpass = transmute(u32)(se),
    dstSubpass = 0,
    srcStageMask = u32(vk.PipelineStageFlagBits.ColorAttachmentOutput | vk.PipelineStageFlagBits.EarlyFragmentTests),
    srcAccessMask = 0,
    dstStageMask = u32(vk.PipelineStageFlagBits.ColorAttachmentOutput | vk.PipelineStageFlagBits.EarlyFragmentTests),
    dstAccessMask = u32(vk.AccessFlagBits.ColorAttachmentWrite | vk.AccessFlagBits.DepthStencilAttachmentWrite),
  };

  attachments := []vk.AttachmentDescription{colorAttachment, depthAttachment};

  renderPassInfo := vk.RenderPassCreateInfo{
    sType = vk.StructureType.RenderPassCreateInfo,
    attachmentCount = u32(len(attachments)),
    pAttachments = mem.raw_slice_data(attachments),
    subpassCount = 1,
    pSubpasses = &subpass,
    dependencyCount = 1,
    pDependencies = &dependency,
  };

  if (vk.create_render_pass(ctx.device, &renderPassInfo, nil, &ctx.renderPass) != vk.Result.Success) {
    return false;
  }
  return true;
}

graphics_choose_swap_surface_format :: proc(availableFormats: []vk.SurfaceFormatKHR) -> vk.SurfaceFormatKHR {
  for af, _ in availableFormats {
    if af.format == vk.Format.B8G8R8A8Srgb && af.colorSpace == vk.ColorSpaceKHR.ColorspaceSrgbNonlinear {
      return af;
    }
  }

  return availableFormats[0];
}


read_file :: proc(filename: string) -> ([]byte, bool) {
  fd, errno := os.open(filename);
  if errno != 0 {
    log.errorf("Failed to open file: %s -- error: %v", filename, errno);
    return nil, false;
  }
  defer os.close(fd);
  size: i64;
  size, errno = os.file_size(fd);
  if errno != 0 {
    log.errorf("Failed to get file size: %s -- error: %v", filename, errno);
    return nil, false;
  }
  result := make([]byte,size);
  _, errno = os.read(fd,result);
  if errno != 0 {
    delete(result);
    log.errorf("Failed to read file: %s error: %v", filename, errno);
    return nil, false;
  }

  return result, true;
}


graphics_create_shader_module :: proc(device: vk.Device, code: []byte) -> (vk.ShaderModule, bool) {
  createInfo := vk.ShaderModuleCreateInfo{
    sType = vk.StructureType.ShaderModuleCreateInfo,
    codeSize = uint(len(code)),
    pCode = transmute(^u32)mem.raw_slice_data(code),
  };

  shaderModule: vk.ShaderModule;
  if vk.create_shader_module(device, &createInfo, nil, &shaderModule) != vk.Result.Success {
    log.error("Error: failed to create shader module");
    return nil, false;
  }

  return shaderModule, true;
}


get_piece_binding_description :: proc() -> []vk.VertexInputBindingDescription {
  bindingDescription := []vk.VertexInputBindingDescription{
    {
      binding = 0,
      stride = size_of(Vertex),
      inputRate = vk.VertexInputRate.Vertex,
    },
    {
      binding = 1,
      stride = size_of(Instance_Data),
      inputRate = vk.VertexInputRate.Instance,
    },
  };

  return bindingDescription;
}


get_piece_attribute_descriptions :: proc() -> []vk.VertexInputAttributeDescription {
  attributeDescriptions := []vk.VertexInputAttributeDescription{
    {
      binding = 0,
      location = 0,
      format = vk.Format.R32G32B32Sfloat,
      offset = u32(offset_of(Vertex, pos)),
    },
    {
      binding = 0,
      location = 1,
      format = vk.Format.R32G32B32Sfloat,
      offset = u32(offset_of(Vertex, normal)),
    },
    {
      binding = 0,
      location = 2,
      format = vk.Format.R32G32Sfloat,
      offset = u32(offset_of(Vertex, uv)),
    },
    {
      binding = 0,
      location = 3,
      format = vk.Format.R32G32B32Sfloat,
      offset = u32(offset_of(Vertex, color)),
    },
    {
      binding = 1,
      location = 4,
      format = vk.Format.R32G32B32Sfloat,
      offset = u32(offset_of(Instance_Data, pos)),
    },
    {
      binding = 1,
      location = 5,
      format = vk.Format.R32G32B32Sfloat,
      offset = u32(offset_of(Instance_Data, rot)),
    },
    {
      binding = 1,
      location = 6,
      format = vk.Format.R32Sfloat,
      offset = u32(offset_of(Instance_Data, scale)),
    },
    {
      binding = 1,
      location = 7,
      format = vk.Format.R32Sint,
      offset = u32(offset_of(Instance_Data, tex_index)),
    },
  };

  return attributeDescriptions;
}


get_board_binding_description :: proc() -> []vk.VertexInputBindingDescription {
  bindingDescription := []vk.VertexInputBindingDescription{
    {
      binding = 0,
      stride = size_of(Vertex),
      inputRate = vk.VertexInputRate.Vertex,
    },
  };

  return bindingDescription;
}


get_board_attribute_descriptions :: proc() -> []vk.VertexInputAttributeDescription {
  attributeDescriptions := []vk.VertexInputAttributeDescription{
    {
      binding = 0,
      location = 0,
      format = vk.Format.R32G32B32Sfloat,
      offset = u32(offset_of(Vertex, pos)),
    },
    {
      binding = 0,
      location = 1,
      format = vk.Format.R32G32B32Sfloat,
      offset = u32(offset_of(Vertex, normal)),
    },
    {
      binding = 0,
      location = 2,
      format = vk.Format.R32G32Sfloat,
      offset = u32(offset_of(Vertex, uv)),
    },
  };

  return attributeDescriptions;
}



load_module :: proc(device: vk.Device, file: string) -> (vk.ShaderModule, bool) {
  code, ok := read_file(file);
  if !ok {
    return nil, false;
  }
  defer delete(code);

  return graphics_create_shader_module(device, code);
}


load_shader :: proc(device: vk.Device, file: string, stage: vk.ShaderStageFlagBits) -> (vk.PipelineShaderStageCreateInfo, bool) {
  module, ok := load_module(device, file);
  if !ok do return vk.PipelineShaderStageCreateInfo{}, false;

  return vk.PipelineShaderStageCreateInfo{
    sType = vk.StructureType.PipelineShaderStageCreateInfo,
    stage = stage,
    module = module,
    pName = "main",
  }, true;
}


graphics_create_graphics_pipeline :: proc(ctx: ^Graphics_Context) -> bool {
  ok: bool;
  background_info: Shader_Info;
  board_info: Shader_Info;
  piece_info: Shader_Info;

  ok = init_shader_info(&background_info,
                       ctx.device,
                       "shaders/background-vert.spv",
                       "shaders/background-frag.spv",
                       nil,
                       nil);
  if !ok do return false;
  defer delete_shader_info(ctx.device, &background_info);
  ok = init_shader_info(&board_info,
                       ctx.device,
                       "shaders/board-vert.spv",
                       "shaders/board-frag.spv",
                       get_board_binding_description(),
                       get_board_attribute_descriptions());
  if !ok do return false;
  defer delete_shader_info(ctx.device, &board_info);
  ok = init_shader_info(&piece_info,
                       ctx.device,
                       "shaders/piece-vert.spv",
                       "shaders/piece-frag.spv",
                       get_piece_binding_description(),
                       get_piece_attribute_descriptions());
  if !ok do return false;
  defer delete_shader_info(ctx.device, &piece_info);

  shader_stages: [2]vk.PipelineShaderStageCreateInfo;

  binding_description := get_piece_binding_description();
  attribute_descriptions := get_piece_attribute_descriptions();

  vertex_input_info := vk.PipelineVertexInputStateCreateInfo{
    sType = vk.StructureType.PipelineVertexInputStateCreateInfo,
    pVertexBindingDescriptions = mem.raw_slice_data(binding_description),
    pVertexAttributeDescriptions = mem.raw_slice_data(attribute_descriptions),
  };

  input_assembly := vk.PipelineInputAssemblyStateCreateInfo{
    sType = vk.StructureType.PipelineInputAssemblyStateCreateInfo,
    topology = vk.PrimitiveTopology.TriangleList,
    primitiveRestartEnable = vk.FALSE,
  };

  viewport := vk.Viewport{
    x = 0.0,
    y = 0.0,
    width = f32(ctx.swapChainExtent.width),
    height = f32(ctx.swapChainExtent.height),
    minDepth = 0.0,
    maxDepth = 1.0,
  };

  scissor := vk.Rect2D{
    offset = {0, 0},
    extent = ctx.swapChainExtent,
  };

  viewport_state := vk.PipelineViewportStateCreateInfo{
    sType = vk.StructureType.PipelineViewportStateCreateInfo,
    viewportCount = 1,
    pViewports = &viewport,
    scissorCount = 1,
    pScissors = &scissor,
  };

  rasterizer := vk.PipelineRasterizationStateCreateInfo{
    sType = vk.StructureType.PipelineRasterizationStateCreateInfo,
    depthClampEnable = vk.FALSE,
    rasterizerDiscardEnable = vk.FALSE,
    polygonMode = vk.PolygonMode.Fill,
    lineWidth = 1.0,
    cullMode = u32(vk.CullModeFlagBits.Back),
    frontFace = vk.FrontFace.CounterClockwise,
    depthBiasEnable = vk.FALSE,
  };

  multisampling := vk.PipelineMultisampleStateCreateInfo{
    sType = vk.StructureType.PipelineMultisampleStateCreateInfo,
    sampleShadingEnable = vk.FALSE,
    rasterizationSamples = vk.SampleCountFlagBits._1,
  };

  depth_stencil := vk.PipelineDepthStencilStateCreateInfo {
    sType = vk.StructureType.PipelineDepthStencilStateCreateInfo,
    depthTestEnable = vk.TRUE,
    depthWriteEnable = vk.TRUE,
    depthCompareOp = vk.CompareOp.Less,
    depthBoundsTestEnable = vk.FALSE,
    stencilTestEnable = vk.FALSE,
  };

  color_blend_attachment := vk.PipelineColorBlendAttachmentState{
    colorWriteMask = u32(vk.ColorComponentFlagBits.R | vk.ColorComponentFlagBits.G | vk.ColorComponentFlagBits.B | vk.ColorComponentFlagBits.A),
    blendEnable = vk.FALSE,
  };

  color_blending := vk.PipelineColorBlendStateCreateInfo{
    sType = vk.StructureType.PipelineColorBlendStateCreateInfo,
    logicOpEnable = vk.FALSE,
    logicOp = vk.LogicOp.Copy,
    attachmentCount = 1,
    pAttachments = &color_blend_attachment,
    blendConstants = { 0.0, 0.0, 0.0, 0.0 },
  };

  pipeline_layout_info := vk.PipelineLayoutCreateInfo{
    sType = vk.StructureType.PipelineLayoutCreateInfo,
    setLayoutCount = 1,
    pSetLayouts = &ctx.descriptor_set_layout,
  };

  if (vk.create_pipeline_layout(ctx.device, &pipeline_layout_info, nil, &ctx.pipeline_layout) != vk.Result.Success) {
    log.error("Error: could not create pipeline layout");
    return false;
  }

  pipeline_info := vk.GraphicsPipelineCreateInfo{
    sType = vk.StructureType.GraphicsPipelineCreateInfo,
    stageCount = 2,
    pStages = mem.raw_slice_data(shader_stages[:]),
    pVertexInputState = &vertex_input_info,
    pInputAssemblyState = &input_assembly,
    pViewportState = &viewport_state,
    pRasterizationState = &rasterizer,
    pMultisampleState = &multisampling,
    pDepthStencilState = &depth_stencil,
    pColorBlendState = &color_blending,
    layout = ctx.pipeline_layout,
    renderPass = ctx.renderPass,
    subpass = 0,
    basePipelineHandle = nil,
  };

  shader_stages[0] = piece_info.vertex_info;
  shader_stages[1] = piece_info.fragment_info;
  vertex_input_info.vertexBindingDescriptionCount = u32(len(piece_info.bindings));
  vertex_input_info.vertexAttributeDescriptionCount = u32(len(piece_info.attributes));
  if vk.create_graphics_pipelines(ctx.device, nil, 1, &pipeline_info, nil, &ctx.piece_pipeline) != vk.Result.Success {
    log.error("Error: failed to create graphics pipleine for piece");
    return false;
  }

  shader_stages[0] = board_info.vertex_info;
  shader_stages[1] = board_info.fragment_info;
  vertex_input_info.vertexBindingDescriptionCount = u32(len(board_info.bindings));
  vertex_input_info.vertexAttributeDescriptionCount = u32(len(board_info.attributes));
  if vk.create_graphics_pipelines(ctx.device, nil, 1, &pipeline_info, nil, &ctx.board_pipeline) != vk.Result.Success {
    vk.destroy_pipeline(ctx.device, ctx.piece_pipeline, nil);
    ctx.piece_pipeline = nil;
    log.error("Error: failed to create graphics pipleine for board");
    return false;
  }

  shader_stages[0] = background_info.vertex_info;
  shader_stages[1] = background_info.fragment_info;
  vertex_input_info.vertexBindingDescriptionCount = 0;
  vertex_input_info.vertexAttributeDescriptionCount = 0;
  if vk.create_graphics_pipelines(ctx.device, nil, 1, &pipeline_info, nil, &ctx.background_pipeline) != vk.Result.Success {
    vk.destroy_pipeline(ctx.device, ctx.piece_pipeline, nil);
    vk.destroy_pipeline(ctx.device, ctx.board_pipeline, nil);
    ctx.piece_pipeline = nil;
    ctx.board_pipeline = nil;
    log.error("Error: failed to create graphics pipleine for background");
    return false;
  }


  return true;
}


graphics_create_framebuffers :: proc(ctx: ^Graphics_Context) -> bool {
  ctx.swapChainFramebuffers = make([]vk.Framebuffer, len(ctx.swapChainImageViews));

  for sciv, i in ctx.swapChainImageViews {
    attachments := []vk.ImageView{sciv, ctx.depthImageView};

    framebufferInfo := vk.FramebufferCreateInfo{
      sType = vk.StructureType.FramebufferCreateInfo,
      renderPass = ctx.renderPass,
      attachmentCount = u32(len(attachments)),
      pAttachments = mem.raw_slice_data(attachments),
      width = ctx.swapChainExtent.width,
      height = ctx.swapChainExtent.height,
      layers = 1,
    };

    if vk.create_framebuffer(ctx.device, &framebufferInfo, nil, &ctx.swapChainFramebuffers[i]) != vk.Result.Success {
      log.error("Error: could not create framebuffer");
      return false;
    }
  }
  return true;
}



graphics_choose_swap_present_mode :: proc(availablePresentModes: []vk.PresentModeKHR) -> vk.PresentModeKHR {
  for apm, _ in availablePresentModes {
    if apm == vk.PresentModeKHR.Mailbox {
      return apm;
    }
  }

  return vk.PresentModeKHR.Fifo;
}


graphics_choose_swap_extent :: proc(ctx: ^Graphics_Context, capabilities: ^vk.SurfaceCapabilitiesKHR) -> vk.Result {
  return vk.get_physical_device_surface_capabilities_khr(ctx.physicalDevice, ctx.surface, capabilities);
}


graphics_create_swap_chain :: proc(ctx: ^Graphics_Context) -> bool {
  surfaceFormat := graphics_choose_swap_surface_format(ctx.formats);
  presentMode := graphics_choose_swap_present_mode(ctx.presentModes);
  if graphics_choose_swap_extent(ctx, &ctx.capabilities) != vk.Result.Success {
    log.error("Error: could not choose a swap extent");
    return false;
  }

  extent := ctx.capabilities.currentExtent;

  imageCount := ctx.capabilities.minImageCount + 1;
  if ctx.capabilities.maxImageCount > 0 && imageCount > ctx.capabilities.maxImageCount {
    imageCount = ctx.capabilities.maxImageCount;
  }

  createInfo := vk.SwapchainCreateInfoKHR{
    sType = vk.StructureType.SwapchainCreateInfoKhr,
    surface = ctx.surface,
    minImageCount = imageCount,
    imageFormat = surfaceFormat.format,
    imageColorSpace = surfaceFormat.colorSpace,
    imageExtent = extent,
    imageArrayLayers = 1,
    imageUsage = u32(vk.ImageUsageFlagBits.ColorAttachment),
  };

  if !graphics_find_queue_families(ctx) {
    return false;
  }
  queueFamilyIndices := []u32{ctx.graphicsFamily, ctx.presentFamily};

  if ctx.graphicsFamily != ctx.presentFamily {
    createInfo.imageSharingMode = vk.SharingMode.Concurrent;
    createInfo.queueFamilyIndexCount = 2;
    createInfo.pQueueFamilyIndices = mem.raw_slice_data(queueFamilyIndices);
  } else {
    createInfo.imageSharingMode = vk.SharingMode.Exclusive;
  }

  createInfo.preTransform = ctx.capabilities.currentTransform;
  createInfo.compositeAlpha = vk.CompositeAlphaFlagBitsKHR.Opaque;
  createInfo.presentMode = presentMode;
  createInfo.clipped = vk.TRUE;

  createInfo.oldSwapchain = nil;

  if vk.create_swapchain_khr(ctx.device, &createInfo, nil, &ctx.swapChain) != vk.Result.Success {
    log.error("Error: could not create swapchains");
    return false;
  }

  vk.get_swapchain_images_khr(ctx.device, ctx.swapChain, &imageCount, nil);
  ctx.swapChainImages = make([]vk.Image,imageCount);
  vk.get_swapchain_images_khr(ctx.device, ctx.swapChain, &imageCount, mem.raw_slice_data(ctx.swapChainImages));

  ctx.swapChainImageFormat = surfaceFormat.format;
  ctx.swapChainExtent = extent;

  return true;
}


graphics_create_image_view :: proc(ctx: ^Graphics_Context, image: vk.Image, format: vk.Format, aspectMask: vk.ImageAspectFlagBits) -> (vk.ImageView, bool) {
  viewInfo := vk.ImageViewCreateInfo {
    sType = vk.StructureType.ImageViewCreateInfo,
    image = image,
    viewType = vk.ImageViewType._2DArray,
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


graphics_create_image_views :: proc(ctx: ^Graphics_Context) -> bool {
  ctx.swapChainImageViews = make([]vk.ImageView,len(ctx.swapChainImages));
  for _, i in ctx.swapChainImageViews {
    view, result := graphics_create_image_view(ctx, ctx.swapChainImages[i], ctx.swapChainImageFormat, vk.ImageAspectFlagBits.Color);
    if !result {
      return false;
    }
    ctx.swapChainImageViews[i] = view;
  }
  return true;
}


graphics_query_swap_chain_support :: proc(ctx: ^Graphics_Context) -> bool {
  if vk.get_physical_device_surface_capabilities_khr(ctx.physicalDevice, ctx.surface, &ctx.capabilities) != vk.Result.Success {
    log.error("Error: unable to get device surface capabilities");
    return false;
  }

  formatCount:u32;
  vk.get_physical_device_surface_formats_khr(ctx.physicalDevice, ctx.surface, &formatCount, nil);
  if formatCount == 0 {
    log.error("Error: unable to get device surface formats");
    return false;
  }
  ctx.formats = make([]vk.SurfaceFormatKHR,formatCount);
  vk.get_physical_device_surface_formats_khr(ctx.physicalDevice, ctx.surface, &formatCount, mem.raw_slice_data(ctx.formats));

  presentModeCount:u32;
  vk.get_physical_device_surface_present_modes_khr(ctx.physicalDevice, ctx.surface, &presentModeCount, nil);
  if presentModeCount == 0 {
    log.error("Error: unable to get device present modes");
    return false;
  }
  ctx.presentModes = make([]vk.PresentModeKHR,presentModeCount);
  vk.get_physical_device_surface_present_modes_khr(ctx.physicalDevice, ctx.surface, &presentModeCount, mem.raw_slice_data(ctx.presentModes));
  return true;
}


graphics_create_logical_device :: proc(ctx: ^Graphics_Context) -> bool {
  queueCreateInfos: []vk.DeviceQueueCreateInfo;
  uniqueQueueFamilies: []u32;
  if ctx.graphicsFamily ==  ctx.presentFamily {
    uniqueQueueFamilies = []u32{ctx.graphicsFamily};
    queueCreateInfos = []vk.DeviceQueueCreateInfo{---};
  } else {
    uniqueQueueFamilies = []u32{ctx.graphicsFamily, ctx.presentFamily};
    queueCreateInfos = []vk.DeviceQueueCreateInfo{---,---};
  }

  queuePriority : f32 = 1.0;
  for qf, i in uniqueQueueFamilies {
    queueCreateInfo := vk.DeviceQueueCreateInfo{
      sType = vk.StructureType.DeviceQueueCreateInfo,
      queueFamilyIndex = qf,
      queueCount = 1,
      pQueuePriorities = &queuePriority,
    };
    queueCreateInfos[i] = queueCreateInfo;
  }

  deviceFeatures := vk.PhysicalDeviceFeatures {
      samplerAnisotropy = vk.TRUE,
  };

  createInfo := vk.DeviceCreateInfo {
    sType = vk.StructureType.DeviceCreateInfo,
    pQueueCreateInfos = mem.raw_slice_data(queueCreateInfos),
    queueCreateInfoCount = u32(len(queueCreateInfos)),
    pEnabledFeatures = &deviceFeatures,
    enabledExtensionCount = u32(len(device_extensions)),
    ppEnabledExtensionNames = mem.raw_slice_data(device_extensions),
    enabledLayerCount = 0,
  };

  if vk.create_device(ctx.physicalDevice, &createInfo, nil, &ctx.device) != vk.Result.Success {
    log.error("Error: could not create logical device");
    return false;
  }

  log.debugf("ctx.device: %v", ctx.device);

  vk.get_device_queue(ctx.device, ctx.graphicsFamily, 0, &ctx.graphicsQueue);
  vk.get_device_queue(ctx.device, ctx.presentFamily, 0, &ctx.presentQueue);

  return true;
}


graphics_create_descriptor_layout :: proc(ctx: ^Graphics_Context) -> bool {
  uboLayoutBinding := vk.DescriptorSetLayoutBinding{
    binding = 0,
    descriptorCount = 1,
    descriptorType = vk.DescriptorType.UniformBuffer,
    pImmutableSamplers = nil,
    stageFlags = u32(vk.ShaderStageFlagBits.Vertex),
  };

  samplerLayoutBinding := vk.DescriptorSetLayoutBinding {
    binding = 1,
    descriptorCount = 1,
    descriptorType = vk.DescriptorType.CombinedImageSampler,
    pImmutableSamplers = nil,
    stageFlags = u32(vk.ShaderStageFlagBits.Fragment),
  };

  bindings := []vk.DescriptorSetLayoutBinding{uboLayoutBinding, samplerLayoutBinding};
  layoutInfo := vk.DescriptorSetLayoutCreateInfo {
    sType = vk.StructureType.DescriptorSetLayoutCreateInfo,
    bindingCount = u32(len(bindings)),
    pBindings = mem.raw_slice_data(bindings),
  };

  if vk.create_descriptor_set_layout(ctx.device, &layoutInfo, nil, &ctx.descriptor_set_layout) != vk.Result.Success {
    log.error("Error: failed to create descriptor layout");
    return false;
  }

  return true;
}


graphics_destroy :: proc(ctx: ^Graphics_Context) {
  vk.device_wait_idle(ctx.device);
  if ctx.depthImageView != nil do vk.destroy_image_view(ctx.device, ctx.depthImageView, nil);
  if ctx.depthImage != nil do vk.destroy_image(ctx.device, ctx.depthImage, nil);
  if ctx.depthImageMemory != nil do vk.free_memory(ctx.device, ctx.depthImageMemory, nil);
  if ctx.texture_sampler != nil do vk.destroy_sampler(ctx.device, ctx.texture_sampler, nil);
  if ctx.texture_image_view != nil do vk.destroy_image_view(ctx.device, ctx.texture_image_view, nil);
  if ctx.texture_image != nil do vk.destroy_image(ctx.device, ctx.texture_image, nil);
  if ctx.texture_image_memory != nil do vk.free_memory(ctx.device, ctx.texture_image_memory, nil);
  if ctx.piece.index_buffer != nil do vk.destroy_buffer(ctx.device, ctx.piece.index_buffer,nil);
  if ctx.piece.index_buffer_memory != nil do vk.free_memory(ctx.device, ctx.piece.index_buffer_memory, nil);
  if ctx.board.index_buffer != nil do vk.destroy_buffer(ctx.device, ctx.board.index_buffer,nil);
  if ctx.board.index_buffer_memory != nil do vk.free_memory(ctx.device, ctx.board.index_buffer_memory, nil);
  if ctx.piece.vertices != nil do delete(ctx.piece.vertices);
  if ctx.piece.indices != nil do delete(ctx.piece.indices);
  if ctx.board.vertices != nil do delete(ctx.piece.vertices);
  if ctx.board.indices != nil do delete(ctx.piece.indices);
  if ctx.piece.vertex_buffer != nil do vk.destroy_buffer(ctx.device, ctx.piece.vertex_buffer,nil);
  if ctx.board.vertex_buffer != nil do vk.destroy_buffer(ctx.device, ctx.board.vertex_buffer,nil);
  if ctx.piece.vertex_buffer_memory != nil do vk.free_memory(ctx.device, ctx.piece.vertex_buffer_memory, nil);
  if ctx.board.vertex_buffer_memory != nil do vk.free_memory(ctx.device, ctx.board.vertex_buffer_memory, nil);

  if len(ctx.renderFinishedSemaphores) > 0 {
    for i := 0; i < max_frames_in_flight; i += 1 {
      vk.destroy_semaphore(ctx.device, ctx.renderFinishedSemaphores[i], nil);
      vk.destroy_semaphore(ctx.device, ctx.imageAvailableSemaphores[i], nil);
      vk.destroy_fence(ctx.device, ctx.inFlightFences[i], nil);
    }
  }

  if ctx.descriptorPool != nil do vk.destroy_descriptor_pool(ctx.device, ctx.descriptorPool, nil);
  if ctx.piece_pipeline != nil do vk.destroy_pipeline(ctx.device, ctx.piece_pipeline, nil);
  if ctx.board_pipeline != nil do vk.destroy_pipeline(ctx.device, ctx.board_pipeline, nil);
  if ctx.background_pipeline != nil do vk.destroy_pipeline(ctx.device, ctx.background_pipeline, nil);

  if ctx.pipeline_layout != nil do vk.destroy_pipeline_layout(ctx.device, ctx.pipeline_layout, nil);
  if ctx.descriptor_set_layout != nil do vk.destroy_descriptor_set_layout(ctx.device, ctx.descriptor_set_layout, nil);
  if ctx.renderPass != nil do vk.destroy_render_pass(ctx.device, ctx.renderPass, nil);
  if ctx.commandPool != nil do vk.destroy_command_pool(ctx.device, ctx.commandPool, nil);
  if ctx.swapChain != nil do vk.destroy_swapchain_khr(ctx.device, ctx.swapChain, nil);

  if len(ctx.swapChainImages) > 0 {
    for _, i in ctx.swapChainImages {
      if ctx.uniform_buffers != nil do vk.destroy_buffer(ctx.device, ctx.uniform_buffers[i], nil);
      if ctx.uniform_buffers_memory != nil do vk.free_memory(ctx.device, ctx.uniform_buffers_memory[i], nil);
      if ctx.swapChainFramebuffers != nil do vk.destroy_framebuffer(ctx.device, ctx.swapChainFramebuffers[i], nil);
      vk.destroy_image_view(ctx.device, ctx.swapChainImageViews[i], nil);
    }
    if ctx.uniform_buffers != nil do delete(ctx.uniform_buffers);
    if ctx.uniform_buffers_memory != nil do delete(ctx.uniform_buffers_memory);
    if ctx.swapChainFramebuffers != nil do delete(ctx.swapChainFramebuffers);
    delete(ctx.swapChainImages);
    delete(ctx.swapChainImageViews);
  }

  if ctx.device != nil do vk.destroy_device(ctx.device, nil);
  vk.destroy_surface_khr(ctx.instance,ctx.surface,nil);
  // sdl.destroy_window(ctx.window);
  vk.destroy_instance(ctx.instance, nil);
  // sdl.quit();
}

extensions :: []cstring {
  vk.KHR_SURFACE_EXTENSION_NAME,
  vk.KHR_XLIB_SURFACE_EXTENSION_NAME,
  vk.KHR_XCB_SURFACE_EXTENSION_NAME,
  vk.KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME,
  vk.KHR_GET_SURFACE_CAPABILITIES_2_EXTENSION_NAME,
};

device_extensions :: []cstring {
  vk.KHR_SWAPCHAIN_EXTENSION_NAME,
};


when bc.VULKAN_VALIDATION {
  validation_layers :: []cstring {
    "VK_LAYER_KHRONOS_validation",
  };

  graphics_check_vulkan_validation_layer_support :: proc() -> bool {
    layerCount: u32;
    vk.enumerate_instance_layer_properties(&layerCount, nil);

    availableLayers := make([]vk.LayerProperties,layerCount);
    vk.enumerate_instance_layer_properties(&layerCount, mem.raw_slice_data(availableLayers));

    for layerName, _ in validation_layers {
      layerFound := false;

      for _, i in availableLayers {
        layerProperties := availableLayers[i];

        if layerName == transmute(cstring)(&layerProperties.layerName) {
          layerFound = true;
          break;
        }
      }

      if !layerFound {
        return false;
      }
    }

    return true;
  }
}


graphics_create_vulkan_instance :: proc(ctx: ^Graphics_Context, application_name: string = "tic-tac-toe") -> bool {
  when bc.VULKAN_VALIDATION {
    if !graphics_check_vulkan_validation_layer_support() {
      log.error("Could not find validation layer support");
      return false;
    }
  }

  capplication_name := strings.clone_to_cstring(application_name, context.temp_allocator);

  // Application info
  applicationInfo : vk.ApplicationInfo;
  applicationInfo.sType = vk.StructureType.ApplicationInfo;
  applicationInfo.pApplicationName = capplication_name;
  applicationInfo.pEngineName = capplication_name;
  applicationInfo.apiVersion = vk.API_VERSION_1_1;

  // Instance info
  instanceCreateInfo := vk.InstanceCreateInfo{
    sType = vk.StructureType.InstanceCreateInfo,
    pApplicationInfo = &applicationInfo,
    enabledExtensionCount = u32(len(extensions)),
    ppEnabledExtensionNames = mem.raw_slice_data(extensions),
  };

  when bc.VULKAN_VALIDATION {
    instanceCreateInfo.enabledLayerCount = u32(len(validation_layers));
    instanceCreateInfo.ppEnabledLayerNames = mem.raw_slice_data(validation_layers);
  } else {
    instanceCreateInfo.enabledLayerCount = 0;
  }

  result := vk.create_instance(&instanceCreateInfo, nil, &ctx.instance);
  if result == vk.Result.Success {
    log.info("Successfully created instance!");
  }
  else {
    log.error("Unable to create instance!");
    return false;
  }

  return true;
}


graphics_find_queue_families :: proc(ctx: ^Graphics_Context) -> bool {
  remaining := 2;
  queueFamilyCount : u32;
  vk.get_physical_device_queue_family_properties(ctx.physicalDevice, &queueFamilyCount, nil);
  queueFamilies := make([]vk.QueueFamilyProperties,queueFamilyCount);
  defer delete(queueFamilies);
  vk.get_physical_device_queue_family_properties(ctx.physicalDevice, &queueFamilyCount, mem.raw_slice_data(queueFamilies));

  for qf, i in queueFamilies {
    if qf.queueFlags & u32(vk.QueueFlagBits.Graphics) != 0 {
      ctx.graphicsFamily = u32(i);
      remaining -= 1;
    }

    presentSupport := vk.Bool32(0);
    vk.get_physical_device_surface_support_khr(ctx.physicalDevice, u32(i), ctx.surface, &presentSupport);
    if presentSupport != 0 {
      ctx.presentFamily = u32(i);
      remaining -= 1;
    }

    if remaining == 0 {
      return true;
    }
  }

  log.debug("Unable to find suitable queue families");
  return false;
}

// graphics_get_inputs :: proc(ctx: ^Graphics_Context) -> i32 {
//   sdl.pump_events();
//   return sdl.peep_events(mem.raw_array_data(&ctx.sdl_events),
//                          max_sdl_events,
//                          sdl.Event_Action.Get_Event,
//                          u32(sdl.Event_Type.First_Event),
//                          u32(sdl.Event_Type.Last_Event));
// }


is_device_suitable :: proc(physicalDevice: vk.PhysicalDevice) -> bool {
  deviceProperties : vk.PhysicalDeviceProperties;
  vk.get_physical_device_properties(physicalDevice, &deviceProperties);
  deviceFeatures : vk.PhysicalDeviceFeatures;
  vk.get_physical_device_features(physicalDevice, &deviceFeatures);
  if deviceProperties.deviceType == vk.PhysicalDeviceType.DiscreteGpu && deviceFeatures.geometryShader != 0 && deviceFeatures.samplerAnisotropy != 0 {
    return true;
  }
  if deviceFeatures.geometryShader != 0 && deviceFeatures.samplerAnisotropy != 0 {
    return true;
  }
  return false;
}


graphics_pick_physical_device :: proc(ctx: ^Graphics_Context) -> bool {
  // Find physical devices
  physicalDevicesCount : u32;
  vk.enumerate_physical_devices(ctx.instance, &physicalDevicesCount, nil);
  if physicalDevicesCount == 0 {
    return false;
  }
  physicalDevices := make([]vk.PhysicalDevice, physicalDevicesCount);
  vk.enumerate_physical_devices(ctx.instance, &physicalDevicesCount, mem.raw_slice_data(physicalDevices));
  log.infof("Found: %d physical devices.", physicalDevicesCount);
  for pd, _ in physicalDevices {
    if is_device_suitable(pd) {
      log.info("** picked a physical device");
      ctx.physicalDevice = pd;
      return true;
    }
  }
  log.error("No suitable physical devices found.");
  return false;
}

package ui

// import "core:fmt"
import "core:mem"
import rt "core:runtime"
import "core:math/bits"
import "core:os"
import sdl "shared:sdl2"
import img "shared:sdl2/image"
import vk "shared:vulkan"
import lin "core:math/linalg"
import time "core:time"
import "core:log"
import "core:strings"

max_frames_in_flight :: 2;

sdl_pixeltype_packed32 :: 6;
sdl_packedorder_rgba :: 4;
sdl_packedlayout_8888 :: 6;

max_sdl_events :: 10;

sdl_define_pixelformat :: proc(type, order , layout, bits, bytes: u32) -> u32 {
    return ((1 << 28) | ((type) << 24) | ((order) << 20) | ((layout) << 16) | ((bits) << 8) | ((bytes) << 0));
}

sdl_pixelformat_rgba8888 := sdl_define_pixelformat(sdl_pixeltype_packed32, sdl_packedorder_rgba, sdl_packedlayout_8888, 32, 4);

UniformBufferObject :: struct {
    model: lin.Matrix4f32,
    view: lin.Matrix4f32,
    proj: lin.Matrix4f32,
}

UIContext :: struct {
  instance : vk.Instance,
  enableValidationLayers : bool,
  device: vk.Device,
  physicalDevice: vk.PhysicalDevice,
  surface: vk.SurfaceKHR,
  graphicsQueue: vk.Queue,
  presentQueue: vk.Queue,
  swapChain: vk.SwapchainKHR,
  swapChainImages: []vk.Image,
  swapChainImageFormat: vk.Format,
  swapChainExtent: vk.Extent2D,
  swapChainImageViews: []vk.ImageView,
  swapChainFramebuffers: []vk.Framebuffer,
  graphicsFamily: u32,
  presentFamily: u32,
  capabilities: vk.SurfaceCapabilitiesKHR,
  formats: []vk.SurfaceFormatKHR,
  presentModes: []vk.PresentModeKHR,
  pipelineLayout: vk.PipelineLayout,
  renderPass: vk.RenderPass,
  commandPool: vk.CommandPool,
  commandBuffers: []vk.CommandBuffer,
  graphicsPipeline: vk.Pipeline,
  imageAvailableSemaphores: []vk.Semaphore,
  renderFinishedSemaphores: []vk.Semaphore,
  inFlightFences: []vk.Fence,
  imagesInFlight: []vk.Fence,
  vertexBuffer: vk.Buffer,
  vertexBufferMemory: vk.DeviceMemory,
  indexBuffer: vk.Buffer,
  indexBufferMemory: vk.DeviceMemory,
  descriptorSetLayout: vk.DescriptorSetLayout,
  uniformBuffers: []vk.Buffer,
  uniformBuffersMemory: []vk.DeviceMemory,
  descriptorPool: vk.DescriptorPool,
  descriptorSets: []vk.DescriptorSet,
  currentFrame: int,
  window: ^sdl.Window,
  framebufferResized: bool,
  startTime: time.Time,
  textureImage: vk.Image,
  textureImageMemory: vk.DeviceMemory,
  textureImageView: vk.ImageView,
  textureSampler: vk.Sampler,
  width: u32,
  height: u32,
  sdl_events: [max_sdl_events]sdl.Event,
}

Vertex :: struct {
    pos: lin.Vector3f32,
    color: lin.Vector3f32,
    texCoord: lin.Vector2f32,
};

// vertices :: []Vertex {
//     {{-0.5, -0.5, 0.0}, {1.0, 0.0, 0.0}, {1.0, 0.0}},
//     {{0.5, -0.5, 0.0}, {0.0, 1.0, 0.0}, {0.0, 0.0}},
//     {{0.5, 0.5, 0.0}, {0.0, 0.0, 1.0}, {0.0, 1.0}},
//     {{-0.5, 0.5, 0.0}, {1.0, 1.0, 1.0}, {1.0, 1.0}},
// };


vertices :: []Vertex {
    {{1.000000, 1.000000, -1.000000}, {1.0, 0.0, 0.0}, {1.0, 0.0}},
    {{1.000000, -1.000000, -1.000000}, {0.0, 1.0, 0.0}, {0.0, 0.0}},
    {{1.000000, 1.000000, 1.000000}, {0.0, 0.0, 1.0}, {0.0, 1.0}},
    {{1.000000, -1.000000, 1.000000}, {1.0, 1.0, 0.0}, {1.0, 1.0}},
    {{-1.000000, 1.000000, -1.000000}, {1.0, 0.0, 1.0}, {1.0, 0.0}},
    {{-1.000000, -1.000000, -1.000000}, {0.0, 1.0, 1.0}, {0.0, 0.0}},
    {{-1.000000, 1.000000, 1.000000}, {0.0, 0.0, 1.0}, {0.0, 1.0}},
    {{-1.000000, -1.000000, 1.000000}, {0.0, 0.0, 0.0}, {1.0, 1.0}},
};

// indices :: []u16 {0,1,2,2,3,0};

indices :: []u16 {0, 4, 6, 6, 2, 0, 3, 2, 6, 6, 7, 3, 7, 6, 4, 4, 5, 7, 5, 1, 3, 3, 7, 5, 1, 0, 2, 2, 3, 1, 5, 4, 0, 0, 1, 5};

ui_init :: proc(ctx: ^UIContext,
                enable_validation_layers: bool = true,
                application_name: string = "tic-tac-toe") -> bool {
  ctx.startTime = time.now();
  ctx.enableValidationLayers = enable_validation_layers;
  if sdl.init(sdl.Init_Flags.Everything) < 0 {
    log.errorf("failed to initialize sdl", sdl.get_error());
    return false;
  }

  if !ui_create_vulkan_instance(ctx, application_name) {
    log.error("Could not create vulkan instance.");
    return false;
  }

  if !ui_pick_physical_device(ctx) {
    log.error("No suitable physical devices found.");
    return false;
  }

  if !ui_check_device_extension_support(ctx) {
    log.error("Device does not support needed extensions");
    return false;
  }

  return true;
}

ui_check_device_extension_support :: proc(ctx: ^UIContext) -> bool {
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

  return len(expected) == 0;
}


ui_create_window :: proc(ctx: ^UIContext,
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

  if !ui_create_surface(ctx) do return false;
  if !ui_find_queue_families(ctx) do return false;
  if !ui_create_logical_device(ctx) do return false;
  if !ui_query_swap_chain_support(ctx) do return false;
  if !ui_create_swap_chain(ctx) do return false;
  if !ui_create_image_views(ctx) do return false;
  if !ui_create_render_pass(ctx) do return false;
  if !ui_create_descriptor_layout(ctx) do return false;
  if !ui_create_graphics_pipeline(ctx) do return false;
  if !ui_create_framebuffers(ctx) do return false;
  if !ui_create_command_pool(ctx) do return false;
  if !ui_create_texture_image(ctx) do return false;
  if !ui_create_texture_image_view(ctx) do return false;
  if !ui_create_texture_sampler(ctx) do return false;
  if !ui_create_vertex_buffer(ctx) do return false;
  if !ui_create_index_buffer(ctx) do return false;
  if !ui_create_uniform_buffers(ctx) do return false;
  if !ui_create_descriptor_pool(ctx) do return false;
  if !ui_create_descriptor_sets(ctx) do return false;
  if !ui_create_command_buffers(ctx) do return false;
  if !ui_create_sync_objects(ctx) do return false;

  return true;
}

ui_draw_frame :: proc(ctx: ^UIContext, window: ^sdl.Window) -> bool {
  vk.wait_for_fences(ctx.device, 1, &ctx.inFlightFences[ctx.currentFrame], vk.TRUE, bits.U64_MAX);

  imageIndex: u32;
  #partial switch vk.acquire_next_image_khr(ctx.device, ctx.swapChain, bits.U64_MAX, ctx.imageAvailableSemaphores[ctx.currentFrame], nil, &imageIndex) {
    case vk.Result.ErrorOutOfDateKhr, vk.Result.SuboptimalKhr:
      return recreate_swap_chain(ctx);
    case vk.Result.Success:
    // nothing
    case:
      log.error("Error: what am I doing here?");
      return false;
  }

  update_uniform_buffer(ctx, imageIndex);

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

  if (vk.queue_submit(ctx.graphicsQueue, 1, &submitInfo, ctx.inFlightFences[ctx.currentFrame]) != vk.Result.Success) {
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
    if !recreate_swap_chain(ctx) {
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

ui_cleanup_swap_chain :: proc(ctx: ^UIContext) -> bool {
  for framebuffer, _ in ctx.swapChainFramebuffers {
    vk.destroy_framebuffer(ctx.device, framebuffer, nil);
  }
  delete(ctx.swapChainFramebuffers);
  ctx.swapChainFramebuffers = nil;

  vk.free_command_buffers(ctx.device, ctx.commandPool, u32(len(ctx.commandBuffers)), mem.raw_slice_data(ctx.commandBuffers));
  delete(ctx.commandBuffers);
  ctx.commandBuffers = nil;

  vk.destroy_pipeline(ctx.device, ctx.graphicsPipeline, nil);
  vk.destroy_pipeline_layout(ctx.device, ctx.pipelineLayout, nil);
  vk.destroy_render_pass(ctx.device, ctx.renderPass, nil);

  for imageView, _ in ctx.swapChainImageViews {
    vk.destroy_image_view(ctx.device, imageView, nil);
  }
  delete(ctx.swapChainImageViews);
  ctx.swapChainImageViews = nil;

  vk.destroy_swapchain_khr(ctx.device, ctx.swapChain, nil);

  for i := 0; i < len(ctx.swapChainImages); i += 1 {
    vk.destroy_buffer(ctx.device, ctx.uniformBuffers[i], nil);
    vk.free_memory(ctx.device, ctx.uniformBuffersMemory[i], nil);
  }
  delete(ctx.uniformBuffers);
  delete(ctx.uniformBuffersMemory);
  ctx.uniformBuffers = nil;
  ctx.uniformBuffersMemory = nil;

  vk.destroy_descriptor_pool(ctx.device, ctx.descriptorPool, nil);

  return true;
}

recreate_swap_chain :: proc(ctx: ^UIContext) -> bool {
  if ctx.width == 0 || ctx.height == 0 do return true;

  vk.device_wait_idle(ctx.device);

  if !ui_cleanup_swap_chain(ctx) {
    return false;
  }
  if !ui_create_swap_chain(ctx) {
    return false;
  }
  if !ui_create_image_views(ctx) {
    return false;
  }
  if !ui_create_render_pass(ctx) {
    return false;
  }
  if !ui_create_graphics_pipeline(ctx) {
    return false;
  }
  if !ui_create_framebuffers(ctx) {
    return false;
  }
  if !ui_create_uniform_buffers(ctx) {
    return false;
  }
  if !ui_create_descriptor_pool(ctx) {
    return false;
  }
  if !ui_create_descriptor_sets(ctx) {
    return false;
  }
  if !ui_create_command_buffers(ctx) {
    return false;
  }
  return true;
}

update_uniform_buffer :: proc(ctx: ^UIContext, currentImage: u32) {
  now := time.now();
  diff := time.duration_seconds(time.diff(ctx.startTime,now));
  ubo := UniformBufferObject {
    model = lin.matrix4_rotate(lin.Float(diff)*lin.radians(f32(90)),lin.VECTOR3F32_Z_AXIS),
    view = lin.matrix4_look_at(lin.Vector3f32{2,2,2},lin.Vector3f32{0,0,0},lin.VECTOR3F32_Z_AXIS),
    proj = lin.matrix4_perspective(lin.radians(f32(45)),lin.Float(ctx.swapChainExtent.width)/lin.Float(ctx.swapChainExtent.height),0.1,10),
  };

  ubo.proj[1][1] *= -1;

  data: rawptr;
  vk.map_memory(ctx.device,ctx.uniformBuffersMemory[currentImage],0,size_of(ubo),0,&data);
  rt.mem_copy_non_overlapping(data,&ubo,size_of(ubo));
  vk.unmap_memory(ctx.device,ctx.uniformBuffersMemory[currentImage]);
}

ui_create_sync_objects :: proc(ctx: ^UIContext) -> bool {
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

ui_create_command_buffers :: proc(ctx: ^UIContext) -> bool {
  ctx.commandBuffers = make([]vk.CommandBuffer,len(ctx.swapChainFramebuffers));

  allocInfo := vk.CommandBufferAllocateInfo{
    sType = vk.StructureType.CommandBufferAllocateInfo,
    commandPool = ctx.commandPool,
    level = vk.CommandBufferLevel.Primary,
    commandBufferCount = u32(len(ctx.commandBuffers)),
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

    clearColor := vk.ClearValue{};
    clearColor.color.float32 = {0.0, 0.0, 0.0, 1.0};

    renderPassInfo.clearValueCount = 1;
    renderPassInfo.pClearValues = &clearColor;

    vk.cmd_begin_render_pass(cb, &renderPassInfo, vk.SubpassContents.Inline);

    vk.cmd_bind_pipeline(cb, vk.PipelineBindPoint.Graphics, ctx.graphicsPipeline);

    vertexBuffers := []vk.Buffer{ctx.vertexBuffer};
    offsets := []vk.DeviceSize{0};
    vk.cmd_bind_vertex_buffers(ctx.commandBuffers[i], 0, 1, mem.raw_slice_data(vertexBuffers), mem.raw_slice_data(offsets));
    vk.cmd_bind_index_buffer(ctx.commandBuffers[i],ctx.indexBuffer,0,vk.IndexType.Uint16);
    vk.cmd_bind_descriptor_sets(ctx.commandBuffers[i], vk.PipelineBindPoint.Graphics, ctx.pipelineLayout, 0, 1, &ctx.descriptorSets[i], 0, nil);
    vk.cmd_draw_indexed(ctx.commandBuffers[i], u32(len(indices)), 1, 0, 0, 0);

    // vk.cmd_draw(cb, 3, 1, 0, 0);

    vk.cmd_end_render_pass(cb);

    if vk.end_command_buffer(cb) != vk.Result.Success {
      log.error("Error: failed to end the command buffer");
      return false;
    }
  }
  return true;
}


ui_create_descriptor_sets :: proc(ctx: ^UIContext) -> bool {
  layouts := make([]vk.DescriptorSetLayout,len(ctx.swapChainImages));
  for _, i in layouts {
      layouts[i] = ctx.descriptorSetLayout;
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
      buffer = ctx.uniformBuffers[i],
      offset = 0,
      range = size_of(UniformBufferObject),
    };

    imageInfo := vk.DescriptorImageInfo {
      imageLayout = vk.ImageLayout.ShaderReadOnlyOptimal,
      imageView = ctx.textureImageView,
      sampler = ctx.textureSampler,
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

ui_create_descriptor_pool :: proc(ctx: ^UIContext) -> bool {
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

ui_create_uniform_buffers :: proc(ctx: ^UIContext) -> bool {
    bufferSize := vk.DeviceSize(size_of(UniformBufferObject));

    ctx.uniformBuffers = make([]vk.Buffer,len(ctx.swapChainImages));
    ctx.uniformBuffersMemory = make([]vk.DeviceMemory,len(ctx.swapChainImages));

    for _, i in ctx.swapChainImages {
        create_buffer(ctx, bufferSize, vk.BufferUsageFlagBits.UniformBuffer, vk.MemoryPropertyFlagBits.HostVisible | vk.MemoryPropertyFlagBits.HostCoherent, &ctx.uniformBuffers[i], &ctx.uniformBuffersMemory[i]);
    }
    return true;
}


ui_create_index_buffer :: proc(ctx: ^UIContext) -> bool {
  bufferSize : vk.DeviceSize = u64(size_of(indices[0]) * len(indices));

  stagingBuffer : vk.Buffer;
  stagingBufferMemory : vk.DeviceMemory;
  create_buffer(ctx, bufferSize, vk.BufferUsageFlagBits.TransferSrc, vk.MemoryPropertyFlagBits.HostVisible | vk.MemoryPropertyFlagBits.HostCoherent, &stagingBuffer, &stagingBufferMemory);

  data : rawptr;
  vk.map_memory(ctx.device, stagingBufferMemory, 0, bufferSize, 0, &data);
  rt.mem_copy_non_overlapping(data, mem.raw_slice_data(indices), int(bufferSize));
  vk.unmap_memory(ctx.device, stagingBufferMemory);

  create_buffer(ctx,bufferSize, vk.BufferUsageFlagBits.TransferDst | vk.BufferUsageFlagBits.IndexBuffer, vk.MemoryPropertyFlagBits.DeviceLocal, &ctx.indexBuffer, &ctx.indexBufferMemory);

  copy_buffer(ctx,stagingBuffer, ctx.indexBuffer, bufferSize);

  vk.destroy_buffer(ctx.device, stagingBuffer, nil);
  vk.free_memory(ctx.device, stagingBufferMemory, nil);

  return true;
}


copy_buffer :: proc(ctx: ^UIContext, srcBuffer: vk.Buffer, dstBuffer: vk.Buffer, size: vk.DeviceSize) {
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


ui_create_vertex_buffer :: proc(ctx: ^UIContext) -> bool {
  bufferSize : vk.DeviceSize = u64(size_of(vertices[0]) * len(vertices));

  stagingBuffer: vk.Buffer;
  stagingBufferMemory: vk.DeviceMemory;
  if !create_buffer(ctx,bufferSize,vk.BufferUsageFlagBits.TransferSrc,vk.MemoryPropertyFlagBits.HostVisible | vk.MemoryPropertyFlagBits.HostCoherent,&stagingBuffer,&stagingBufferMemory) {
    return false;
  }

  data: rawptr;
  vk.map_memory(ctx.device, stagingBufferMemory, 0, bufferSize, 0, &data);
  rt.mem_copy_non_overlapping(data, mem.raw_slice_data(vertices), int(bufferSize));
  vk.unmap_memory(ctx.device, stagingBufferMemory);

  if !create_buffer(ctx,bufferSize,vk.BufferUsageFlagBits.TransferDst | vk.BufferUsageFlagBits.VertexBuffer, vk.MemoryPropertyFlagBits.DeviceLocal,&ctx.vertexBuffer,&ctx.vertexBufferMemory) {
    log.error("Error: failed to create buffer");
    return false;
  }

  copy_buffer(ctx,stagingBuffer,ctx.vertexBuffer,bufferSize);

  vk.destroy_buffer(ctx.device,stagingBuffer,nil);
  vk.free_memory(ctx.device,stagingBufferMemory,nil);

  return true;
}


ui_create_texture_sampler :: proc(ctx: ^UIContext) -> bool {
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

  if vk.create_sampler(ctx.device, &samplerInfo, nil, &ctx.textureSampler) != vk.Result.Success {
    log.error("Error: failed to create texture sampler!");
    return false;
  }
  return true;
}

ui_create_texture_image_view :: proc(ctx: ^UIContext) -> bool {
  textureImageView, result := ui_create_image_view(ctx, ctx.textureImage, vk.Format.R8G8B8A8Srgb);
  ctx.textureImageView = textureImageView;
  return result;
}

find_memory_type :: proc(ctx:^UIContext, typeFilter:u32, properties: vk.MemoryPropertyFlags) -> (u32, bool) {
  memProperties := vk.PhysicalDeviceMemoryProperties{};
  vk.get_physical_device_memory_properties(ctx.physicalDevice, &memProperties);

  for i : u32 = 0; i < memProperties.memoryTypeCount; i += 1 {
    if (typeFilter & (1 << i)) != 0 && (memProperties.memoryTypes[i].propertyFlags & properties) == properties {
      return i, true;
    }
  }

  return 0, false;
}

create_buffer :: proc(ctx: ^UIContext, size: vk.DeviceSize, usage: vk.BufferUsageFlagBits, properties: vk.MemoryPropertyFlagBits, buffer: ^vk.Buffer, bufferMemory: ^vk.DeviceMemory) -> bool {
  bufferInfo := vk.BufferCreateInfo {
    sType = vk.StructureType.BufferCreateInfo,
    size = u64(size),
    usage = u32(usage),
    sharingMode = vk.SharingMode.Exclusive,
  };

  if (vk.create_buffer(ctx.device, &bufferInfo, nil, buffer) != vk.Result.Success) {
    return false;
  }

  memRequirements: vk.MemoryRequirements;
  vk.get_buffer_memory_requirements(ctx.device, buffer^, &memRequirements);

  memoryTypeIndex, ok := find_memory_type(ctx, memRequirements.memoryTypeBits, u32(properties));

  if !ok {
    return false;
  }

  allocInfo := vk.MemoryAllocateInfo{
    sType = vk.StructureType.MemoryAllocateInfo,
    allocationSize = memRequirements.size,
    memoryTypeIndex = memoryTypeIndex,
  };

  if vk.allocate_memory(ctx.device, &allocInfo, nil, bufferMemory) != vk.Result.Success {
      return false;
  }

  vk.bind_buffer_memory(ctx.device, buffer^, bufferMemory^, 0);
  return true;
}


create_image :: proc(ctx: ^UIContext, width, height: u32, format: vk.Format, tiling: vk.ImageTiling, usage: vk.ImageUsageFlagBits, properties: vk.MemoryPropertyFlagBits, image: ^vk.Image, imageMemory: ^vk.DeviceMemory) -> bool {
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

  mt, ok := find_memory_type(ctx, memRequirements.memoryTypeBits, u32(properties));
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

begin_single_time_commands :: proc(ctx: ^UIContext) -> vk.CommandBuffer {
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

end_single_time_commands :: proc(ctx: ^UIContext, commandBuffer: ^vk.CommandBuffer) {
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

copy_buffer_to_image :: proc(ctx: ^UIContext, buffer: vk.Buffer, image: vk.Image, width, height: u32) {
  commandBuffer := begin_single_time_commands(ctx);

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

  end_single_time_commands(ctx, &commandBuffer);
}


transition_image_layout :: proc(ctx: ^UIContext, image: vk.Image, format: vk.Format, oldLayout: vk.ImageLayout, newLayout: vk.ImageLayout) -> bool {
  commandBuffer := begin_single_time_commands(ctx);

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

  end_single_time_commands(ctx, &commandBuffer);

  return true;
}



ui_create_texture_image :: proc(ctx: ^UIContext) -> bool {
  origImageSurface := img.load("textures/texture.jpg");
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

  if !create_buffer(ctx, imageSize, vk.BufferUsageFlagBits.TransferSrc, vk.MemoryPropertyFlagBits.HostVisible | vk.MemoryPropertyFlagBits.HostCoherent, &stagingBuffer, &stagingBufferMemory) {
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

  if !create_image(ctx, u32(texWidth), u32(texHeight), vk.Format.R8G8B8A8Srgb,vk.ImageTiling.Optimal, vk.ImageUsageFlagBits.TransferDst | vk.ImageUsageFlagBits.Sampled, vk.MemoryPropertyFlagBits.DeviceLocal, &ctx.textureImage, &ctx.textureImageMemory) {
    log.error("Error: could not create image");
    return false;
  }

  if !transition_image_layout(ctx, ctx.textureImage, vk.Format.R8G8B8A8Srgb, vk.ImageLayout.Undefined, vk.ImageLayout.TransferDstOptimal) {
      return false;
  }
  copy_buffer_to_image(ctx, stagingBuffer, ctx.textureImage, u32(texWidth), u32(texHeight));
  if !transition_image_layout(ctx, ctx.textureImage, vk.Format.R8G8B8A8Srgb, vk.ImageLayout.TransferDstOptimal, vk.ImageLayout.ShaderReadOnlyOptimal) {
      return false;
  }

  return true;
}


ui_create_command_pool :: proc(ctx: ^UIContext) -> bool {
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

ui_create_render_pass :: proc(ctx: ^UIContext) -> bool {
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

  colorAttachmentRef := vk.AttachmentReference{
    attachment = 0,
    layout = vk.ImageLayout.ColorAttachmentOptimal,
  };

  subpass := vk.SubpassDescription{
    pipelineBindPoint = vk.PipelineBindPoint.Graphics,
    colorAttachmentCount = 1,
    pColorAttachments = &colorAttachmentRef,
  };

  renderPassInfo := vk.RenderPassCreateInfo{
    sType = vk.StructureType.RenderPassCreateInfo,
    attachmentCount = 1,
    pAttachments = &colorAttachment,
    subpassCount = 1,
    pSubpasses = &subpass,
  };

  if (vk.create_render_pass(ctx.device, &renderPassInfo, nil, &ctx.renderPass) != vk.Result.Success) {
    return false;
  }
  return true;
}

ui_choose_swap_surface_format :: proc(availableFormats: []vk.SurfaceFormatKHR) -> vk.SurfaceFormatKHR {
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


create_shader_module :: proc(ctx: ^UIContext, code: []byte) -> (vk.ShaderModule, bool) {
  createInfo := vk.ShaderModuleCreateInfo{};
  createInfo.sType = vk.StructureType.ShaderModuleCreateInfo;
  createInfo.codeSize = uint(len(code));
  createInfo.pCode = transmute(^u32)mem.raw_slice_data(code);

  shaderModule: vk.ShaderModule;
  if vk.create_shader_module(ctx.device, &createInfo, nil, &shaderModule) != vk.Result.Success {
    log.error("Error: failed to create shader module");
    return nil, false;
  }

  return shaderModule, true;
}


get_binding_description :: proc() -> vk.VertexInputBindingDescription {
  bindingDescription := vk.VertexInputBindingDescription{
    binding = 0,
    stride = size_of(Vertex),
    inputRate = vk.VertexInputRate.Vertex,
  };

  return bindingDescription;
}

get_attribute_descriptions :: proc() -> []vk.VertexInputAttributeDescription {
  attributeDescriptions := []vk.VertexInputAttributeDescription{
    {
      binding = 0,
      location = 0,
      format = vk.Format.R32G32B32Sfloat,
      offset = u32(offset_of(Vertex,pos)),
    },
    {
      binding = 0,
      location = 1,
      format = vk.Format.R32G32B32Sfloat,
      offset = u32(offset_of(Vertex,color)),
    },
    {
      binding = 0,
      location = 2,
      format = vk.Format.R32G32Sfloat,
      offset = u32(offset_of(Vertex, texCoord)),
    },
  };

  return attributeDescriptions;
}

ui_create_graphics_pipeline :: proc(ctx: ^UIContext) -> bool {
  vertShaderCode, ok := read_file("shaders/vert.spv");
  if !ok {
    return false;
  }
  defer delete(vertShaderCode);
  fragShaderCode: []byte;
  fragShaderCode, ok = read_file("shaders/frag.spv");
  defer delete(fragShaderCode);
  if !ok {
    return false;
  }

  vertShaderModule: vk.ShaderModule;
  vertShaderModule, ok = create_shader_module(ctx, vertShaderCode);
  if !ok {
    return false;
  }
  defer vk.destroy_shader_module(ctx.device, vertShaderModule, nil);
  fragShaderModule: vk.ShaderModule;
  fragShaderModule, ok = create_shader_module(ctx, fragShaderCode);
  if !ok {
    return false;
  }
  defer vk.destroy_shader_module(ctx.device, fragShaderModule, nil);

  vertShaderStageInfo := vk.PipelineShaderStageCreateInfo{
    sType = vk.StructureType.PipelineShaderStageCreateInfo,
    stage = vk.ShaderStageFlagBits.Vertex,
    module = vertShaderModule,
    pName = "main",
  };

  fragShaderStageInfo := vk.PipelineShaderStageCreateInfo{
    sType = vk.StructureType.PipelineShaderStageCreateInfo,
    stage = vk.ShaderStageFlagBits.Fragment,
    module = fragShaderModule,
    pName = "main",
  };

  shaderStages := []vk.PipelineShaderStageCreateInfo{vertShaderStageInfo, fragShaderStageInfo};

  bindingDescription := get_binding_description();
  attributeDescriptions := get_attribute_descriptions();

  vertexInputInfo := vk.PipelineVertexInputStateCreateInfo{
    sType = vk.StructureType.PipelineVertexInputStateCreateInfo,
    vertexBindingDescriptionCount = 1,
    vertexAttributeDescriptionCount = u32(len(attributeDescriptions)),
    pVertexBindingDescriptions = &bindingDescription,
    pVertexAttributeDescriptions = mem.raw_slice_data(attributeDescriptions),
  };

  inputAssembly := vk.PipelineInputAssemblyStateCreateInfo{
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

  viewportState := vk.PipelineViewportStateCreateInfo{
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

  colorBlendAttachment := vk.PipelineColorBlendAttachmentState{
    colorWriteMask = u32(vk.ColorComponentFlagBits.R | vk.ColorComponentFlagBits.G | vk.ColorComponentFlagBits.B | vk.ColorComponentFlagBits.A),
    blendEnable = vk.FALSE,
  };

  colorBlending := vk.PipelineColorBlendStateCreateInfo{
    sType = vk.StructureType.PipelineColorBlendStateCreateInfo,
    logicOpEnable = vk.FALSE,
    logicOp = vk.LogicOp.Copy,
    attachmentCount = 1,
    pAttachments = &colorBlendAttachment,
    blendConstants = { 0.0, 0.0, 0.0, 0.0 },
  };

  pipelineLayoutInfo := vk.PipelineLayoutCreateInfo{
    sType = vk.StructureType.PipelineLayoutCreateInfo,
    setLayoutCount = 1,
    pSetLayouts = &ctx.descriptorSetLayout,
  };

  if (vk.create_pipeline_layout(ctx.device, &pipelineLayoutInfo, nil, &ctx.pipelineLayout) != vk.Result.Success) {
    log.error("Error: could not create pipeline layout");
    return false;
  }

  pipelineInfo := vk.GraphicsPipelineCreateInfo{
    sType = vk.StructureType.GraphicsPipelineCreateInfo,
    stageCount = 2,
    pStages = mem.raw_slice_data(shaderStages),
    pVertexInputState = &vertexInputInfo,
    pInputAssemblyState = &inputAssembly,
    pViewportState = &viewportState,
    pRasterizationState = &rasterizer,
    pMultisampleState = &multisampling,
    pColorBlendState = &colorBlending,
    layout = ctx.pipelineLayout,
    renderPass = ctx.renderPass,
    subpass = 0,
    basePipelineHandle = nil,
  };

  if vk.create_graphics_pipelines(ctx.device, nil, 1, &pipelineInfo, nil, &ctx.graphicsPipeline) != vk.Result.Success {
    log.error("Error: failed to create graphics pipleine");
    return false;
  }

  return true;
}

ui_create_framebuffers :: proc(ctx: ^UIContext) -> bool {
  ctx.swapChainFramebuffers = make([]vk.Framebuffer, len(ctx.swapChainImageViews));

  for sciv, i in ctx.swapChainImageViews {
    attachments := []vk.ImageView{sciv};

    framebufferInfo := vk.FramebufferCreateInfo{
      sType = vk.StructureType.FramebufferCreateInfo,
      renderPass = ctx.renderPass,
      attachmentCount = 1,
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



ui_choose_swap_present_mode :: proc(availablePresentModes: []vk.PresentModeKHR) -> vk.PresentModeKHR {
  for apm, _ in availablePresentModes {
    if apm == vk.PresentModeKHR.Mailbox {
      return apm;
    }
  }

  return vk.PresentModeKHR.Fifo;
}

ui_choose_swap_extent :: proc(ctx: ^UIContext, capabilities: ^vk.SurfaceCapabilitiesKHR) -> vk.Result {
  return vk.get_physical_device_surface_capabilities_khr(ctx.physicalDevice, ctx.surface, capabilities);
}

ui_create_swap_chain :: proc(ctx: ^UIContext) -> bool {
  surfaceFormat := ui_choose_swap_surface_format(ctx.formats);
  presentMode := ui_choose_swap_present_mode(ctx.presentModes);
  if ui_choose_swap_extent(ctx, &ctx.capabilities) != vk.Result.Success {
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

  if !ui_find_queue_families(ctx) {
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

ui_create_image_view :: proc(ctx: ^UIContext, image: vk.Image, format: vk.Format) -> (vk.ImageView, bool) {
  viewInfo := vk.ImageViewCreateInfo {
    sType = vk.StructureType.ImageViewCreateInfo,
    image = image,
    viewType = vk.ImageViewType._2D,
    format = format,
    subresourceRange = {
      aspectMask = u32(vk.ImageAspectFlagBits.Color),
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

ui_create_image_views :: proc(ctx: ^UIContext) -> bool {
  ctx.swapChainImageViews = make([]vk.ImageView,len(ctx.swapChainImages));
  for _, i in ctx.swapChainImageViews {
    view, result := ui_create_image_view(ctx, ctx.swapChainImages[i], ctx.swapChainImageFormat);
    if !result {
      return false;
    }
    ctx.swapChainImageViews[i] = view;
  }
  return true;
}


ui_query_swap_chain_support :: proc(ctx: ^UIContext) -> bool {
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

ui_create_logical_device :: proc(ctx: ^UIContext) -> bool {
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

ui_create_descriptor_layout :: proc(ctx: ^UIContext) -> bool {
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

  if vk.create_descriptor_set_layout(ctx.device, &layoutInfo, nil, &ctx.descriptorSetLayout) != vk.Result.Success {
    log.error("Error: failed to create descriptor layout");
    return false;
  }

  return true;
}


ui_destroy :: proc(ctx: ^UIContext) {
  vk.device_wait_idle(ctx.device);
  if ctx.textureSampler != nil do vk.destroy_sampler(ctx.device, ctx.textureSampler, nil);
  if ctx.textureImageView != nil do vk.destroy_image_view(ctx.device, ctx.textureImageView, nil);
  if ctx.textureImage != nil do vk.destroy_image(ctx.device, ctx.textureImage, nil);
  if ctx.textureImageMemory != nil do vk.free_memory(ctx.device, ctx.textureImageMemory, nil);

  if ctx.indexBuffer != nil do vk.destroy_buffer(ctx.device, ctx.indexBuffer,nil);
  if ctx.indexBufferMemory != nil do vk.free_memory(ctx.device, ctx.indexBufferMemory, nil);
  if ctx.vertexBuffer != nil do vk.destroy_buffer(ctx.device, ctx.vertexBuffer,nil);
  if ctx.vertexBufferMemory != nil do vk.free_memory(ctx.device, ctx.vertexBufferMemory, nil);

  if len(ctx.renderFinishedSemaphores) > 0 {
    for i := 0; i < max_frames_in_flight; i += 1 {
      vk.destroy_semaphore(ctx.device, ctx.renderFinishedSemaphores[i], nil);
      vk.destroy_semaphore(ctx.device, ctx.imageAvailableSemaphores[i], nil);
      vk.destroy_fence(ctx.device, ctx.inFlightFences[i], nil);
    }
  }

  if ctx.descriptorPool != nil do vk.destroy_descriptor_pool(ctx.device, ctx.descriptorPool, nil);
  if ctx.graphicsPipeline != nil do vk.destroy_pipeline(ctx.device, ctx.graphicsPipeline, nil);
  if ctx.pipelineLayout != nil do vk.destroy_pipeline_layout(ctx.device, ctx.pipelineLayout, nil);
  if ctx.descriptorSetLayout != nil do vk.destroy_descriptor_set_layout(ctx.device, ctx.descriptorSetLayout, nil);
  if ctx.renderPass != nil do vk.destroy_render_pass(ctx.device, ctx.renderPass, nil);
  if ctx.commandPool != nil do vk.destroy_command_pool(ctx.device, ctx.commandPool, nil);
  if ctx.swapChain != nil do vk.destroy_swapchain_khr(ctx.device, ctx.swapChain, nil);

  if len(ctx.swapChainImages) > 0 {
    for _, i in ctx.swapChainImages {
      if ctx.uniformBuffers != nil do vk.destroy_buffer(ctx.device, ctx.uniformBuffers[i], nil);
      if ctx.uniformBuffersMemory != nil do vk.free_memory(ctx.device, ctx.uniformBuffersMemory[i], nil);
      if ctx.swapChainFramebuffers != nil do vk.destroy_framebuffer(ctx.device, ctx.swapChainFramebuffers[i], nil);
      vk.destroy_image_view(ctx.device, ctx.swapChainImageViews[i], nil);
    }
    if ctx.uniformBuffers != nil do delete(ctx.uniformBuffers);
    if ctx.uniformBuffersMemory != nil do delete(ctx.uniformBuffersMemory);
    if ctx.swapChainFramebuffers != nil do delete(ctx.swapChainFramebuffers);
    delete(ctx.swapChainImages);
    delete(ctx.swapChainImageViews);
  }

  if ctx.device != nil do vk.destroy_device(ctx.device, nil);
  vk.destroy_surface_khr(ctx.instance,ctx.surface,nil);
  sdl.destroy_window(ctx.window);
  vk.destroy_instance(ctx.instance, nil);
  sdl.quit();
}

extensions :: []cstring {
  vk.KHR_SURFACE_EXTENSION_NAME,
  vk.KHR_XLIB_SURFACE_EXTENSION_NAME,
  vk.KHR_XCB_SURFACE_EXTENSION_NAME,
  vk.KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME,
  vk.KHR_GET_SURFACE_CAPABILITIES_2_EXTENSION_NAME,
};

validation_layers :: []cstring {
  "VK_LAYER_KHRONOS_validation",
};

device_extensions :: []cstring {
  vk.KHR_SWAPCHAIN_EXTENSION_NAME,
};


ui_check_vulkan_validation_layer_support :: proc() -> bool {
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


ui_create_vulkan_instance :: proc(ctx : ^UIContext, application_name: string = "tic-tac-toe") -> bool {
  // TODO(jim) Make this conditional based on the kind of build we are doing
  if ctx.enableValidationLayers && !ui_check_vulkan_validation_layer_support() {
    log.error("Could not find validation layer support");
    return false;
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

  if ctx.enableValidationLayers {
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

ui_find_queue_families :: proc(ctx: ^UIContext) -> bool {
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

ui_create_surface :: proc(ctx: ^UIContext) -> bool {
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

ui_loop :: proc(ctx: ^UIContext) -> bool {
  event: sdl.Event;
  stop:
  for {
    for sdl.poll_event(&event) != 0 {
      #partial switch event.type {
      case sdl.Event_Type.Quit:
        break stop;
      case sdl.Event_Type.Window_Event:
        #partial switch event.window.event {
        case sdl.Window_Event_ID.Resized:
          log.debug("RESIZED!!");
          log.debugf("new size: %d %d\n",event.window.data1,event.window.data2);
          ctx.width = u32(event.window.data1);
          ctx.height = u32(event.window.data2);
          sdl.update_window_surface(ctx.window);
        case sdl.Window_Event_ID.Exposed:
          log.debug("EXPOSED!!");
          sdl.update_window_surface(ctx.window);
        case sdl.Window_Event_ID.Shown:
          log.debug("SHOWN!!");
          sdl.update_window_surface(ctx.window);
        }
      case:
      }
    }
  }
  return true;
}

ui_get_error :: proc(ctx: ^UIContext) -> string {
  err := sdl.get_error();
  return rt.cstring_to_string(err);
}

ui_get_inputs :: proc(ctx: ^UIContext) -> i32 {
  sdl.pump_events();
  return sdl.peep_events(mem.raw_array_data(&ctx.sdl_events),
                         max_sdl_events,
                         sdl.Event_Action.Get_Event,
                         u32(sdl.Event_Type.First_Event),
                         u32(sdl.Event_Type.Last_Event));
}

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

ui_pick_physical_device :: proc(ctx: ^UIContext) -> bool {
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
  return false;
}

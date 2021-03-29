package build_config

_TOOLKIT :: #config(TOOLKIT, "undefined");

when _TOOLKIT == "undefined" {
  #panic("TOOLKIT is undefined!");
  TOOLKIT :: "undefined";
} else {
  TOOLKIT :: _TOOLKIT;
}

VULKAN_VALIDATION :: #config(VULKAN_VALIDATION, false);

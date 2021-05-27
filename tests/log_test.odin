package tests

import "core:log"
import "core:fmt"

main :: proc() {
  context.logger = log.create_console_logger(lowest = log.Level.Info);
  fmt.println("debug");
  log.debug("debug");
  log.info("info");
  fmt.println("info");
  log.warn("warn");
  fmt.println("warn");
  log.error("error");
  fmt.println("error");
  log.fatal("fatal");
  fmt.println("fatal");
}
package tsync

import "core:time"
import "../futex"
import "core:intrinsics"

wait_group_wait_on :: proc(wg: ^Wait_Group) {
  fake := transmute(^u32)(&wg.wait_value);
  futex.wait(fake, time.MAX_DURATION);
}

wait_group_wake_all :: proc(wg: ^Wait_Group) {
  fake := transmute(^u32)(&wg.wait_value);
  futex.wake_all(fake);
}
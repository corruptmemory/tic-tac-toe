// +build linux, darwin, freebsd
package tsync

import "core:time"
import "../futex"
import "core:intrinsics"

raw_channel_wait_queue_wait_on :: proc(state: ^uintptr, timeout: time.Duration) {
  fake := transmute(^u32)(state);
  futex.wait(fake, timeout);
}

raw_channel_wait_queue_signal :: proc(q: ^Raw_Channel_Wait_Queue) {
  for x := q; x != nil; x = x.next {
    fake := transmute(^u32)(x.state);
    futex.wake_one(fake);
  }
}

raw_channel_wait_queue_broadcast :: proc(q: ^Raw_Channel_Wait_Queue) {
  for x := q; x != nil; x = x.next {
    fake := transmute(^u32)(x.state);
    futex.wake_all(fake);
  }
}

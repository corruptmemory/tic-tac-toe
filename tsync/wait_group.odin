package tsync

import "intrinsics"

Wait_Group :: struct {
  counter: int,
  wait_value: uintptr,
}

wait_group_init :: proc(wg: ^Wait_Group, counter: int = 0) {
  wg.counter = counter;
  wg.wait_value = 0;
}

atomic_add :: proc(dst: ^$T, val: T) -> T {
  o := intrinsics.atomic_add(dst, val);
  return o + val;
}

wait_group_add :: proc(wg: ^Wait_Group, delta: int) {
  if delta == 0 {
    return;
  }

  ctr := atomic_add(&wg.counter, delta);
  if wg.wait_value != 0 {
    panic("tsync.Wait_Group misuse: tsync.wait_group_add called concurrently with tsync.wait_group_wait");
  }

  if ctr < 0 {
    panic("tsync.Wait_Group negative counter");
  }
  if ctr == 0 {
    if wg.wait_value != 0 {
      panic("tsync.Wait_Group misuse: tsync.wait_group_add called concurrently with tsync.wait_group_wait");
    }
    wait_group_wake_all(wg);
  }
}

wait_group_done :: proc(wg: ^Wait_Group) {
  wait_group_add(wg, -1);
}

wait_group_wait :: proc(wg: ^Wait_Group) {
  if _, ok := intrinsics.atomic_cxchg(&wg.counter, 0, 0); ok {
    intrinsics.atomic_store(&wg.wait_value,1);
    return;
  }

  wait_group_wait_on(wg);
}


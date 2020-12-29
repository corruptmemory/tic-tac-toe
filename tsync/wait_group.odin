package tsync

import "intrinsics"
import csync "core:sync"

Wait_Group :: struct {
  counter: int,
  mutex:   csync.Blocking_Mutex,
  cond:    csync.Condition,
}

wait_group_init :: proc(wg: ^Wait_Group) {
  wg.counter = 0;
  csync.blocking_mutex_init(&wg.mutex);
  csync.condition_init(&wg.cond, &wg.mutex);
}


wait_group_destroy :: proc(wg: ^Wait_Group) {
  csync.condition_destroy(&wg.cond);
  csync.blocking_mutex_destroy(&wg.mutex);
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

  if ctr < 0 {
    panic("sync.Wait_Group negative counter");
  }
  if ctr == 0 {
    csync.condition_broadcast(&wg.cond);
    ctr = intrinsics.atomic_load(&wg.counter);
    if ctr != 0 {
      panic("sync.Wait_Group misuse: sync.wait_group_add called concurrently with sync.wait_group_wait");
    }
  }
}

wait_group_done :: proc(wg: ^Wait_Group) {
  wait_group_add(wg, -1);
}

wait_group_wait :: proc(wg: ^Wait_Group) {
  ctr := intrinsics.atomic_load(&wg.counter);

  if ctr > 0 {
    csync.blocking_mutex_lock(&wg.mutex);
    csync.condition_wait_for(&wg.cond);
    csync.blocking_mutex_unlock(&wg.mutex);
    ctr = intrinsics.atomic_load(&wg.counter);
    if ctr != 0 {
      panic("sync.Wait_Group misuse: sync.wait_group_add called concurrently with sync.wait_group_wait");
    }
  }
}


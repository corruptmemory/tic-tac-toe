package tsync

import "core:sync"
import "core:mem"
import "core:time"
import "core:intrinsics"
import "core:runtime"
import futex "../futex"

Wait_Slot :: u32;

channel_logic :: enum u32 {
  zero_zero,
  nonzero_zero,
  zero_nonzero,
  nonzero_nonzero,
}


Channel :: struct(T: typeid) {
  count:            u32,
  logic:            channel_logic,
  cap:              u32,           // total data in the queue
  data_offset:      u16,           // points to an array of dataqsiz bytes
  slot_size:        u32,
  elem_size:        u32,
  closed:           bool,
  sendx:            u32,           // send index
  recvx:            u32,           // receive index
  lock:             sync.Mutex,
  send_wait_slot:   Wait_Slot,
  read_wait_slot:   Wait_Slot,
  allocator:        mem.Allocator,
}



channel_make :: proc($T: typeid, cap : uint = 0, allocator : mem.Allocator = context.allocator) -> ^Channel(T) {
  C :: Channel(T);
  elt_size := size_of(T);
  logic: channel_logic;
  logic_set: bool = false;
  logical_cap: uint = 0;
  c : ^C;

  switch {
    case cap == 0 && elt_size == 0:
      logic = .zero_zero;
      logic_set = true;
      fallthrough;
    case cap > 0 && elt_size == 0:
      if !logic_set {
        logic = .nonzero_zero;
      }
      c = (^C)(mem.alloc(size_of(C), align_of(C), allocator));
      if c == nil {
        return nil;
      }

      c.data_offset = 0;
      c.slot_size = 0;
      c.elem_size = u32(elt_size);
      c.logic = logic;
    case cap == 0 && elt_size > 0:
      logic = .zero_nonzero;
      logical_cap = 1;
      logic_set = true;
      fallthrough;
    case cap > 0 && elt_size > 0:
      if !logic_set {
        logic = .nonzero_nonzero;
        logical_cap = cap;
      }
      elem_align := align_of(T);
      slot_size := mem.align_forward_int(size_of(T), elem_align);
      assert(int(u32(slot_size)) == slot_size);

      s := size_of(C);
      s = mem.align_forward_int(s, elem_align);
      data_offset := u16(s);
      s += slot_size * int(logical_cap);

      a := max(elem_align, align_of(C));
      c = (^C)(mem.alloc(s, a, allocator));
      if c == nil {
        return nil;
      }

      c.data_offset = data_offset;
      c.slot_size = u32(slot_size);
      c.elem_size = u32(elt_size);
      c.logic = logic;
  }

  c.cap = u32(cap);
  c.count = 0;
  c.send_wait_slot = 1;
  c.read_wait_slot = 1;
  c.sendx = 0;
  c.recvx = 0;
  sync.mutex_init(&c.lock);
  c.allocator = context.allocator;
  c.closed = false;

  return c;
}

channel_destroy :: proc (ch: ^Channel($T)) {
  sync.mutex_destroy(&ch.lock);
  mem.free(ch, ch.allocator);
}

channel_close :: proc (ch: ^Channel($T), loc := #caller_location) {
  sync.mutex_lock(&ch.lock);
  defer sync.mutex_unlock(&ch.lock);
  if ch.closed {
    panic("error: attempted to close a closed channel", loc);
  }
  ch.closed = true;
  futex.wake_all(&ch.read_wait_slot);
}

channel_send :: proc (ch: ^Channel($T), data: T, loc := #caller_location) {
  if !channel_try_send(ch, data, true) {
    panic("error: attempted to send on a closed channel", loc);
  }
}

channel_try_send :: proc (ch: ^Channel($T), data: T, block : bool = true) -> bool {
  data := data;
  switch ch.logic {
    case .zero_zero:
      for {
        sync.mutex_lock(&ch.lock);
        if ch.closed {
          sync.mutex_unlock(&ch.lock);
          return false;
        }
        if futex.wake_all(&ch.read_wait_slot) == 0 {
          if !block || ch.closed {
            sync.mutex_unlock(&ch.lock);
            return false;
          }
          ch.send_wait_slot = 0;
          sync.mutex_unlock(&ch.lock);
          futex.wait(&ch.send_wait_slot,time.MAX_DURATION);
        } else {
            sync.mutex_unlock(&ch.lock);
            return true;
        }
      }
    case .nonzero_zero:
      for {
        sync.mutex_lock(&ch.lock);
        if ch.closed {
          sync.mutex_unlock(&ch.lock);
          return false;
        }
        if ch.count < ch.cap {
          ch.count += 1;
          if futex.wake_all(&ch.read_wait_slot) == 0 {
            if !block || ch.closed {
              sync.mutex_unlock(&ch.lock);
              return false;
            }
            ch.send_wait_slot = 0;
            sync.mutex_unlock(&ch.lock);
            futex.wait(&ch.send_wait_slot,time.MAX_DURATION);
          } else {
            sync.mutex_unlock(&ch.lock);
            return true;
          }
        } else {
          if !block || ch.closed {
            sync.mutex_unlock(&ch.lock);
            return false;
          }
          ch.send_wait_slot = 0;
          sync.mutex_unlock(&ch.lock);
          futex.wait(&ch.send_wait_slot,time.MAX_DURATION);
        }
      }
    case .zero_nonzero:
      for {
        sync.mutex_lock(&ch.lock);
        if ch.closed {
          sync.mutex_unlock(&ch.lock);
          return false;
        }
        if ch.count < 1 {
          target := rawptr(uintptr(ch) + uintptr(ch.data_offset));
          runtime.mem_copy_non_overlapping(target,&data,int(ch.elem_size));
          ch.count += 1;
          for {
            if futex.wake_all(&ch.read_wait_slot) > 0 {
              sync.mutex_unlock(&ch.lock);
              return true;
            } else {
              if !block || ch.closed {
                sync.mutex_unlock(&ch.lock);
                return false;
              }
              ch.send_wait_slot = 0;
              sync.mutex_unlock(&ch.lock);
              futex.wait(&ch.send_wait_slot,time.MAX_DURATION);
              sync.mutex_lock(&ch.lock);
            }
          }
        } else {
          ch.send_wait_slot = 0;
          sync.mutex_unlock(&ch.lock);
          futex.wait(&ch.send_wait_slot,time.MAX_DURATION);
        }
      }
    case .nonzero_nonzero:
      for {
        sync.mutex_lock(&ch.lock);
        if ch.closed {
          sync.mutex_unlock(&ch.lock);
          return false;
        }
        if ch.count < ch.cap {
          target := rawptr(uintptr(ch) + uintptr(ch.data_offset) + uintptr(ch.slot_size * ch.sendx));
          runtime.mem_copy_non_overlapping(target,&data,int(ch.elem_size));
          ch.count += 1;
          ch.sendx = (ch.sendx + 1) % ch.cap;
          futex.wake_all(&ch.read_wait_slot);
          sync.mutex_unlock(&ch.lock);
          return true;
        } else {
          if !block || ch.closed {
            sync.mutex_unlock(&ch.lock);
            return false;
          }
          ch.send_wait_slot = 0;
          sync.mutex_unlock(&ch.lock);
          futex.wait(&ch.send_wait_slot,time.MAX_DURATION);
        }
      }
  }
  unreachable();
}

channel_receive :: proc (ch: ^Channel($T), loc := #caller_location) -> T {
  r, ok := channel_try_receive(ch, true);
  if !ok {
    return {};
  }
  return r;
}

channel_try_receive :: proc (ch: ^Channel($T), block : bool = true) -> (T, bool) {
  switch ch.logic {
    case .zero_zero:
      for {
        sync.mutex_lock(&ch.lock);
        if futex.wake_all(&ch.send_wait_slot) == 0 {
          if !block || ch.closed {
            sync.mutex_unlock(&ch.lock);
            return {}, false;
          }
          ch.read_wait_slot = 0;
          sync.mutex_unlock(&ch.lock);
          futex.wait(&ch.read_wait_slot,time.MAX_DURATION);
        } else {
          sync.mutex_unlock(&ch.lock);
          return {}, true;
        }
      }
    case .nonzero_zero:
      for {
        sync.mutex_lock(&ch.lock);
        if ch.count > 0 {
          if ch.count == ch.cap {
            futex.wake_all(&ch.send_wait_slot);
          }
          ch.count -= 1;
          sync.mutex_unlock(&ch.lock);
          return {}, true;
        } else {
          if !block || ch.closed {
            sync.mutex_unlock(&ch.lock);
            return {}, false;
          }
          ch.read_wait_slot = 0;
          sync.mutex_unlock(&ch.lock);
          futex.wait(&ch.read_wait_slot,time.MAX_DURATION);
        }
      }
    case .zero_nonzero:
      for {
        sync.mutex_lock(&ch.lock);
        if ch.count == 1 {
          source := rawptr(uintptr(ch) + uintptr(ch.data_offset));
          data: T;
          runtime.mem_copy_non_overlapping(&data,source,int(ch.elem_size));
          ch.count -= 1;
          futex.wake_all(&ch.send_wait_slot);
          sync.mutex_unlock(&ch.lock);
          return data, true;
        } else {
          if !block || ch.closed {
            sync.mutex_unlock(&ch.lock);
            return {}, false;
          }
          ch.read_wait_slot = 0;
          sync.mutex_unlock(&ch.lock);
          futex.wait(&ch.read_wait_slot,time.MAX_DURATION);
        }
      }
    case .nonzero_nonzero:
      for {
        sync.mutex_lock(&ch.lock);
        if ch.count > 0 {
          if ch.count == ch.cap {
            futex.wake_all(&ch.send_wait_slot);
          }
          source := rawptr(uintptr(ch) + uintptr(ch.data_offset) + uintptr(ch.slot_size * ch.recvx));
          data: T;
          runtime.mem_copy_non_overlapping(&data,source,int(ch.elem_size));
          ch.count -= 1;
          ch.recvx = (ch.recvx + 1) % ch.cap;
          sync.mutex_unlock(&ch.lock);
          return data, true;
        } else {
          if !block || ch.closed {
            sync.mutex_unlock(&ch.lock);
            return {}, false;
          }
          ch.read_wait_slot = 0;
          sync.mutex_unlock(&ch.lock);
          futex.wait(&ch.read_wait_slot,time.MAX_DURATION);
        }
      }
  }
  unreachable();
}
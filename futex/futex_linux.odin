package futex

import "core:time"
import "core:os"
import "core:intrinsics"
import "core:math/bits"
import "core:fmt"

foreign import libc "system:c"

@(default_calling_convention = "c")
foreign libc {
  @(link_name="perror")           perror              :: proc(str: cstring) ---;
}

FUTEX_WAIT :: 0;
FUTEX_WAKE :: 1;
FUTEX_FD :: 2;
FUTEX_REQUEUE :: 3;
FUTEX_CMP_REQUEUE :: 4;
FUTEX_WAKE_OP :: 5;
FUTEX_LOCK_PI :: 6;
FUTEX_UNLOCK_PI :: 7;
FUTEX_TRYLOCK_PI :: 8;
FUTEX_WAIT_BITSET :: 9;
FUTEX_WAKE_BITSET :: 10;
FUTEX_WAIT_REQUEUE_PI :: 11;
FUTEX_CMP_REQUEUE_PI :: 12;

FUTEX_PRIVATE_FLAG :: 128;
FUTEX_CLOCK_REALTIME :: 256;
FUTEX_CMD_MASK :: ~int(FUTEX_PRIVATE_FLAG | FUTEX_CLOCK_REALTIME);

FUTEX_WAIT_PRIVATE :: (FUTEX_WAIT | FUTEX_PRIVATE_FLAG);
FUTEX_WAKE_PRIVATE :: (FUTEX_WAKE | FUTEX_PRIVATE_FLAG);
FUTEX_REQUEUE_PRIVATE :: (FUTEX_REQUEUE | FUTEX_PRIVATE_FLAG);
FUTEX_CMP_REQUEUE_PRIVATE :: (FUTEX_CMP_REQUEUE | FUTEX_PRIVATE_FLAG);
FUTEX_WAKE_OP_PRIVATE :: (FUTEX_WAKE_OP | FUTEX_PRIVATE_FLAG);
FUTEX_LOCK_PI_PRIVATE :: (FUTEX_LOCK_PI | FUTEX_PRIVATE_FLAG);
FUTEX_UNLOCK_PI_PRIVATE :: (FUTEX_UNLOCK_PI | FUTEX_PRIVATE_FLAG);
FUTEX_TRYLOCK_PI_PRIVATE :: (FUTEX_TRYLOCK_PI | FUTEX_PRIVATE_FLAG);
FUTEX_WAIT_BITSET_PRIVATE :: (FUTEX_WAIT_BITSET | FUTEX_PRIVATE_FLAG);
FUTEX_WAKE_BITSET_PRIVATE :: (FUTEX_WAKE_BITSET | FUTEX_PRIVATE_FLAG);
FUTEX_WAIT_REQUEUE_PI_PRIVATE :: (FUTEX_WAIT_REQUEUE_PI | FUTEX_PRIVATE_FLAG);
FUTEX_CMP_REQUEUE_PI_PRIVATE :: (FUTEX_CMP_REQUEUE_PI | FUTEX_PRIVATE_FLAG);


FUTEX_WAITERS :: 0x80000000;

/*
 * The kernel signals via this bit that a thread holding a futex
 * has exited without unlocking the futex. The kernel also does
 * a FUTEX_WAKE on such futexes, after setting the bit, to wake
 * up any possible waiters:
 */
FUTEX_OWNER_DIED :: 0x40000000;

/*
 * The rest of the robust-futex field is for the TID:
 */
FUTEX_TID_MASK :: 0x3fffffff;

/*
 * This limit protects against a deliberately circular list.
 * (Not worth introducing an rlimit for it)
 */
ROBUST_LIST_LIMIT :: 2048;

/*
 * bitset with all bits set for the FUTEX_xxx_BITSET OPs to request a
 * match of any bit.
 */
FUTEX_BITSET_MATCH_ANY :: 0xffffffff;


FUTEX_OP_SET :: 0;  /* *(int *)UADDR2 = OPARG; */
FUTEX_OP_ADD :: 1;  /* *(int *)UADDR2 += OPARG; */
FUTEX_OP_OR :: 2;  /* *(int *)UADDR2 |= OPARG; */
FUTEX_OP_ANDN :: 3;  /* *(int *)UADDR2 &= ~OPARG; */
FUTEX_OP_XOR :: 4;  /* *(int *)UADDR2 ^= OPARG; */

FUTEX_OP_OPARG_SHIFT :: 8;  /* Use (1 << OPARG) instead of OPARG.  */

FUTEX_OP_CMP_EQ :: 0;  /* if (oldval == CMPARG) wake */
FUTEX_OP_CMP_NE :: 1;  /* if (oldval != CMPARG) wake */
FUTEX_OP_CMP_LT :: 2;  /* if (oldval < CMPARG) wake */
FUTEX_OP_CMP_LE :: 3;  /* if (oldval <= CMPARG) wake */
FUTEX_OP_CMP_GT :: 4;  /* if (oldval > CMPARG) wake */
FUTEX_OP_CMP_GE :: 5;  /* if (oldval >= CMPARG) wake */

/* FUTEX_WAKE_OP will perform atomically
   int oldval = *(int *)UADDR2;
   *(int *)UADDR2 = oldval OP OPARG;
   if (oldval CMP CMPARG)
     wake UADDR2;  */


make_futex_op :: proc(op: int, oparg: int, cmp: int, cmparg: int) -> int {
  return (((op & 0xf) << 28) | ((cmp & 0xf) << 24) | ((oparg & 0xfff) << 12) | (cmparg & 0xfff));
}

SYS_FUTEX : os.Syscall : 202;


futex :: proc(uaddr: ^u32,
             futex_op: int,
             val: u32,
             timeout: ^time.TimeSpec,
             uaddr2: ^u32,
             val3: u32) -> i32 {
  return os.syscall(SYS_FUTEX, uaddr, futex_op, val, timeout, uaddr2, val3);
}

wait :: proc(futexp: ^u32, timeout: time.Duration) -> i32 {
  ts: time.TimeSpec;
  tsp: ^time.TimeSpec = nil;

  if timeout != time.MAX_DURATION {
    sec := i64(timeout / time.Second);
    nsec := i64(timeout % time.Second);
    ts.tv_sec = sec;
    ts.tv_nsec = nsec;
    tsp = &ts;
  }

   /* atomic_compare_exchange_strong(ptr, oldval, newval)
      atomically performs the equivalent of:

          if (*ptr == *oldval)
              *ptr = newval;

      It returns true if the test yielded true and *ptr was updated. */
   /* Is the futex available? */
   l := intrinsics.atomic_load(futexp);
   if l == 1 {
       return 0;
   }

   /* Futex is not available; wait */

   s := futex(futexp, FUTEX_WAIT_PRIVATE, 0, tsp, nil, 0);
   errno := os.Errno(os.get_last_error());
   if s == -1 && errno != os.EAGAIN {
     perror("futex-FUTEX_WAIT");
     panic(fmt.tprintf("futex-FUTEX_WAIT - %v - %v",s,errno));
   }
   return s;
}

wake_n :: proc(futexp: ^u32, to_wake: u32 = 1) -> i32 {
   if _, ok := intrinsics.atomic_cxchg(futexp, 0, 1); ok {
       s := futex(futexp, FUTEX_WAKE_PRIVATE, to_wake, nil, nil, 0);
       if s == -1 {
         panic(fmt.tprintf("futex-FUTEX_WAKE_ONE: %v", s));
       }
       return s;
   }
   return 0;
}


wake_all :: proc(futexp: ^u32) -> i32 {
  return wake_n(futexp, bits.I32_MAX);
}

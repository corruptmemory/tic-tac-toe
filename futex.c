/* futex_demo.c

  Usage: futex_demo [nloops]
                   (Default: 5)

  Demonstrate the use of futexes in a program where parent and child
  use a pair of futexes located inside a shared anonymous mapping to
  synchronize access to a shared resource: the terminal. The two
  processes each write 'num-loops' messages to the terminal and employ
  a synchronization protocol that ensures that they alternate in
  writing messages.
*/
#define _GNU_SOURCE
#include <stdio.h>
#include <errno.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/mman.h>
#include <sys/syscall.h>
#include <linux/futex.h>
#include <sys/time.h>
#include <pthread.h>

#define errExit(msg)    do { perror(msg); exit(EXIT_FAILURE); \
                       } while (0)


#define handle_error_en(en, msg) \
       do { errno = en; perror(msg); exit(EXIT_FAILURE); } while (0)

#define handle_error(msg) \
       do { perror(msg); exit(EXIT_FAILURE); } while (0)

static uint32_t *futex1, *futex2;
static int nloops = 5;

static int
futex(uint32_t *uaddr, int futex_op, uint32_t val,
     const struct timespec *timeout, uint32_t *uaddr2, uint32_t val3)
{
   return syscall(SYS_futex, uaddr, futex_op, val,
                  timeout, uaddr2, val3);
}

/* Acquire the futex pointed to by 'futexp': wait for its value to
  become 1, and then set the value to 0. */

static void
fwait(uint32_t *futexp)
{
   long s;

   /* atomic_compare_exchange_strong(ptr, oldval, newval)
      atomically performs the equivalent of:

          if (*ptr == *oldval)
              *ptr = newval;

      It returns true if the test yielded true and *ptr was updated. */

   while (1) {

       /* Is the futex available? */
       const uint32_t one = 1;
       if (atomic_compare_exchange_strong(futexp, &one, 0))
           break;      /* Yes */

       /* Futex is not available; wait */

       s = futex(futexp, FUTEX_WAIT_PRIVATE, 0, NULL, NULL, 0);
       if (s == -1 && errno != EAGAIN)
           errExit("futex-FUTEX_WAIT");
   }
}

/* Release the futex pointed to by 'futexp': if the futex currently
  has the value 0, set its value to 1 and the wake any futex waiters,
  so that if the peer is blocked in fwait(), it can proceed. */

static void
fpost(uint32_t *futexp)
{
   long s;

   /* atomic_compare_exchange_strong() was described
      in comments above */

   const uint32_t zero = 0;
   if (atomic_compare_exchange_strong(futexp, &zero, 1)) {
       s = futex(futexp, FUTEX_WAKE_PRIVATE, 1, NULL, NULL, 0);
       if (s  == -1)
           errExit("futex-FUTEX_WAKE");
   }
}

static void *
thread1(void *arg)
{
   struct pthread_t *tinfo = arg;
   char *uargv;

   for (int j = 0; j < nloops; j++) {
       fwait(futex2);
       printf("Parent %d\n", j);
       fpost(futex1);
   }
}

static void *
thread2(void *arg)
{
   struct pthread_t *tinfo = arg;
   char *uargv;

  for (int j = 0; j < nloops; j++) {
       fwait(futex1);
       printf("Child %d\n", j);
       fpost(futex2);
   }
}

int
main(int argc, char *argv[])
{
  pthread_attr_t attr;
  pthread_t thread1_id, thread2_id;
  setbuf(stdout, NULL);

  /* Create a shared anonymous mapping that will hold the futexes.
     Since the futexes are being shared between processes, we
     subsequently use the "shared" futex operations (i.e., not the
     ones suffixed "_PRIVATE") */

  uint32_t iaddr[2];

  futex1 = &iaddr[0];
  futex2 = &iaddr[1];

  printf("SYS_futex: %d\n", SYS_futex);

  *futex1 = 0;        /* State: unavailable */
  *futex2 = 1;        /* State: available */

  /* Create a child process that inherits the shared anonymous
     mapping */

  int s, opt, num_threads;
  void *res;

  /* The "-s" option specifies a stack size for our threads */
  /* Initialize thread creation attributes */

  s = pthread_attr_init(&attr);
  if (s != 0)
     handle_error_en(s, "pthread_attr_init");

  s = pthread_attr_setstacksize(&attr, 0x100000);
  if (s != 0)
     handle_error_en(s, "pthread_attr_setstacksize");


  s = pthread_create(&thread1_id, &attr,
                     &thread1, &thread1_id);
  if (s != 0)
     handle_error_en(s, "pthread_create");

  s = pthread_create(&thread2_id, &attr,
                     &thread2, &thread2_id);
  if (s != 0)
     handle_error_en(s, "pthread_create");

  s = pthread_attr_destroy(&attr);
  if (s != 0)
     handle_error_en(s, "pthread_attr_destroy");

  s = pthread_join(thread1_id, &res);
  if (s != 0)
   handle_error_en(s, "pthread_join");

  s = pthread_join(thread2_id, &res);
  if (s != 0)
   handle_error_en(s, "pthread_join");

  exit(EXIT_SUCCESS);
}

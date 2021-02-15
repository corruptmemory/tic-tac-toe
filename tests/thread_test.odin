package tests

import "core:log"
import "core:thread"
import "core:math/rand"
import "core:time"
import "../tsync"

thread_test :: proc() {
  thread_arg :: struct {
    id: i32,
    awg: ^tsync.Wait_Group,
    bwg: ^tsync.Wait_Group,
  };
  log.info("Wait group test started");

  athread :: proc(t: ^thread.Thread) {
    context.logger = log.create_console_logger(lowest = log.Level.Info);
    rng := rand.create(u64(time.now()._nsec));
    delay := time.Duration(rand.int31_max(4900, &rng) + 100);
    arg := transmute(^thread_arg)t.user_args[0];
    defer free(arg);
    log.infof("A: starting thread %d", arg.id);
    time.sleep(delay * time.Millisecond);
    tsync.wait_group_done(arg.awg);
    log.infof("A: ** finished thread %d", arg.id);
  }
  bthread :: proc(t: ^thread.Thread) {
    context.logger = log.create_console_logger(lowest = log.Level.Info);
    arg := transmute(^thread_arg)t.user_args[0];
    defer free(arg);
    log.infof("B: starting thread %d", arg.id);
    tsync.wait_group_wait(arg.awg);
    tsync.wait_group_done(arg.bwg);
    log.infof("B: ~~ finished thread %d", arg.id);
  }
  awg := tsync.Wait_Group{};
  tsync.wait_group_init(&awg);
  bwg := tsync.Wait_Group{};
  tsync.wait_group_init(&bwg);
  athreads : [100]^thread.Thread;
  bthreads : [100]^thread.Thread;
  for i : i32 = 0; i < 100; i += 1 {
    tsync.wait_group_add(&awg, 1);
    ctx1 := new(thread_arg);
    ctx1.id = i;
    ctx1.awg = &awg;
    ctx1.bwg = &bwg;
    t1 := thread.create(athread);
    athreads[i] = t1;
    t1.user_index = 1;
    t1.user_args[0] = ctx1;
    thread.start(t1);
  }

  for i : i32 = 0; i < 100; i += 1 {
    tsync.wait_group_add(&bwg, 1);
    ctx1 := new(thread_arg);
    ctx1.id = i;
    ctx1.awg = &awg;
    ctx1.bwg = &bwg;
    t1 := thread.create(bthread);
    bthreads[i] = t1;
    t1.user_index = 1;
    t1.user_args[0] = ctx1;
    thread.start(t1);
  }

  tsync.wait_group_wait(&bwg);
  for i := 0; i < len(athreads); i += 1 {
    thread.destroy(athreads[i]);
    thread.destroy(bthreads[i]);
  }
  log.info("Wait group test FINISHED");
}

main :: proc() {
    thread_test();
}

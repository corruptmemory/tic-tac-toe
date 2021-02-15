package tests

import "core:log"
import "core:time"
import "core:thread"
import "../tsync"
import "core:math/rand"


channel_test :: proc() {
  thread_arg :: struct {
    id: i32,
    channel: ^tsync.Channel(int),
    awg: ^tsync.Wait_Group,
    bwg: ^tsync.Wait_Group,
  };
  log.info("Channel test started");

  athread :: proc(t: ^thread.Thread) {
    context.logger = log.create_console_logger(lowest = log.Level.Info);
    arg := transmute(^thread_arg)t.user_args[0];
    defer free(arg);
    ch := arg.channel;
    log.infof("A: starting thread %d", arg.id);
    for i := 0; i < 10000000; i += 1 {
      tsync.channel_send(ch, i);
    }
    tsync.channel_close(ch);
    tsync.wait_group_done(arg.awg);
    log.infof("A: ** finished thread %d", arg.id);
  }
  bthread :: proc(t: ^thread.Thread) {
    context.logger = log.create_console_logger(lowest = log.Level.Info);
    arg := transmute(^thread_arg)t.user_args[0];
    defer free(arg);
    ch := arg.channel;
    log.infof("B: starting thread %d", arg.id);
    for {
      _, ok := tsync.channel_try_receive(ch);
      // log.infof("id: %d, x: %v, ok: %v", arg.id, x, ok);
      if !ok do break;
    }
    tsync.wait_group_done(arg.bwg);
    log.infof("B: ~~ finished thread %d", arg.id);
  }
  awg := tsync.Wait_Group{};
  tsync.wait_group_init(&awg);
  tsync.wait_group_add(&awg, 1);
  bwg := tsync.Wait_Group{};
  tsync.wait_group_init(&bwg);
  tsync.wait_group_add(&bwg, 2);

  channel := tsync.channel_make(int, 10000000);

  ctxb1 := new(thread_arg);
  ctxb1.id = 1;
  ctxb1.channel = channel;
  ctxb1.awg = &awg;
  ctxb1.bwg = &bwg;
  tb1 := thread.create(bthread);
  tb1.user_index = 1;
  tb1.user_args[0] = ctxb1;
  thread.start(tb1);

  ctxb2 := new(thread_arg);
  ctxb2.id = 2;
  ctxb2.channel = channel;
  ctxb2.awg = &awg;
  ctxb2.bwg = &bwg;
  tb2 := thread.create(bthread);
  tb2.user_index = 1;
  tb2.user_args[0] = ctxb2;
  thread.start(tb2);

  ctxa := new(thread_arg);
  ctxa.id = 0;
  ctxa.channel = channel;
  ctxa.awg = &awg;
  ctxa.bwg = &bwg;
  ta := thread.create(athread);
  ta.user_index = 1;
  ta.user_args[0] = ctxa;
  thread.start(ta);


  tsync.wait_group_wait(&awg);
  tsync.wait_group_wait(&bwg);
  thread.destroy(ta);
  thread.destroy(tb1);
  thread.destroy(tb2);
  tsync.channel_destroy(channel);
  log.info("Channel test FINISHED");
}


main :: proc() {
   channel_test();
}

package main

// import "flags"
import "core:log"
import "core:fmt"
import "core:time"
// import "ui"
import "input"
import "core:thread"
import "tsync"
import "core:math/rand"

// CliArgs :: struct {
//   a: int `short:"a" long:"a-name" description:"The A argument" required:"true" default:"123"`,
//   a1: int `short:"A" long:"a1-name" description:"The A1 argument"`,
//   b: string `short:"b" long:"b-name" description:"The B argument" required:"true"`,
//   c: u64 `short:"c" long:"c-name" description:"The C argument" required:"true"`,
//   d: bool `long:"d-name" description:"The D argument" required:"true"`,
// };

print_ui_state :: proc(uiState: ^input.UIState) {
  changed: bool;

  for _, i in uiState.keys {
    if uiState.keys[i].changed {
      changed = true;
      break;
    }
  }

  if changed {
    fmt.println("***********");
    for _, i in uiState.keys {
      fmt.printf("%v: %v\n", uiState.keys[i].key, uiState.keys[i].upDown);
    }
  }
}


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
  empty :: struct{};
  fmt.printf("size_of(empty): %d\n", size_of(empty));
  context.logger = log.create_console_logger(lowest = log.Level.Info);
  channel_test();
  // thread_test();
  // uiState: input.UIState;
  // input.init(&uiState);
  // fmt.printf("uiState: %v\n", uiState);

  // // if parser, ok := flags.new_parser("tic-tac-toe", "The game of tic-tac-toe", CliArgs); ok {
  // //   defer flags.delete_parser(&parser);
  // //   flags.print_help(parser);
  // // }
  // ctx : ui.Context;

  // if ui.connect_display(&ctx, nil) {
  //   fmt.printf("Connected: %v\n", ctx.conn);
  //   defer ui.disconnect_display(&ctx);
  //   ui.init(&ctx);

  //   keyMap := ui.InputMap  {
  //     up = 'w',
  //     down = 's',
  //     left = 'a',
  //     right = 'd',
  //     select = ' ',
  //     exit = 'p',
  //   };

  //   if ok := ui.set_input_map(&ctx, keyMap); !ok {
  //     fmt.println("error: failed to set input map");
  //   }

  //   ui.start(&ctx);
  //   // ui.show_keyboard_mapping(&ctx);

  //   if w, wok := ui.create_window(&ctx); wok {
  //     for ui.get_input_state(&ctx,&uiState) {
  //       print_ui_state(&uiState);
  //       if input.should_exit(&uiState) {
  //         break;
  //       }
  //       time.nanosleep(1000000);
  //     }
  //     ui.shutdown(&ctx,w);
  //   }
  // }
}

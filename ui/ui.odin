package ui

import "shared:x11/xcb"
import "core:mem"
import "core:os"
import input "../input"
import "core:fmt"
import tsync "../tsync"
import "core:runtime"
import "core:thread"
import "core:log"
import "core:time"

KeymapEntry :: struct {
    keycode: xcb.Keycode,
    xk: XK,
    char: rune
}

InputMap :: struct {
    up: rune,
    down: rune,
    left: rune,
    right: rune,
    select: rune,
    exit: rune,
}

TrackingState :: struct {
    keycode: xcb.Keycode,
    key: input.Key,
    upDown: input.KeyUpDown,
}

GetInputRequest :: struct {
    uiState: ^input.UIState,
    done: ^tsync.Channel(bool),
}

XcbEvent :: union #no_nil {
    xcb.GenericEvent,
    bool,
}

Context :: struct {
    conn: ^xcb.Connection,
    setup: ^xcb.Setup,
    screen: ^xcb.Screen,
    keyMap: [256]KeymapEntry,
    trackingState: [int(input.Key.LAST)]TrackingState,
    xcbChannel: ^tsync.Channel(XcbEvent),
    getInputChannel: ^tsync.Channel(GetInputRequest),
    uiWaitGroup: tsync.Wait_Group,
    xcbWaitGroup: tsync.Wait_Group,
    xcbThread: ^thread.Thread,
    uiThread: ^thread.Thread,
}

Window :: struct {
    id: u32,
}

eventMask :: ~u8(0x80);

send_xcb_event :: proc(ctx: ^Context, event: xcb.GenericEvent) {
    evt := XcbEvent(event);
    tsync.channel_send(ctx.xcbChannel,evt);
}

send_xcb_done :: proc(ctx: ^Context) {
    evt := XcbEvent(bool(true));
    tsync.channel_send(ctx.xcbChannel,evt);
}

xcb_input_loop :: proc(ctx: ^Context) {
    cleanup_and_exit :: proc(ctx: ^Context) {
        send_xcb_done(ctx);
        tsync.channel_close(ctx.xcbChannel);
        tsync.wait_group_done(&ctx.xcbWaitGroup);
    }
    defer cleanup_and_exit(ctx);
    log.info("started: xcb_input_loop");


    for event := wait_for_event(ctx); event != nil; event = wait_for_event(ctx) {
        // log.infof("got event: %v", event);
        send_xcb_event(ctx,event^);
        free_event(event);
    }
}

connect_display :: proc(ctx: ^Context, display: cstring) -> bool {
    ctx.conn = xcb.connect(display,nil);
    if ctx.conn == nil {
        return false;
    }

    return true;
}

init :: proc(ctx: ^Context) {
    ctx.setup = xcb.get_setup(ctx.conn);
    ctx.screen = xcb.setup_roots_iterator(ctx.setup).data;
    tsync.wait_group_init(&ctx.uiWaitGroup);
    tsync.wait_group_init(&ctx.xcbWaitGroup);
    ctx.xcbChannel = tsync.channel_make(XcbEvent, 10);
    ctx.getInputChannel = tsync.channel_make(GetInputRequest, 1);
    init_keybaord_mapping(ctx);
}

start :: proc(ctx: ^Context) {
    piw :: proc(t: ^thread.Thread) {
        context.logger = log.create_console_logger(lowest = log.Level.Info);
        poll_input_loop(transmute(^Context)t.user_args[0]);
    }
    xcbw :: proc(t: ^thread.Thread) {
        context.logger = log.create_console_logger(lowest = log.Level.Info);
        xcb_input_loop(transmute(^Context)t.user_args[0]);
    }
    ctx.uiThread = thread.create(piw);
    ctx.uiThread.user_index = 1;
    ctx.uiThread.user_args[0] = ctx;
    ctx.xcbThread = thread.create(xcbw);
    ctx.xcbThread.user_index = 1;
    ctx.xcbThread.user_args[0] = ctx;
    tsync.wait_group_add(&ctx.uiWaitGroup, 1);
    tsync.wait_group_add(&ctx.xcbWaitGroup, 1);
    thread.start(ctx.uiThread);
    thread.start(ctx.xcbThread);
}

find_key_map_entry_by_rune :: proc(ctx: ^Context, char: rune) -> (KeymapEntry, bool) {
    for e, _ in ctx.keyMap {
        if char == e.char {
            return e, true;
        }
    }

    return KeymapEntry{}, false;
}

set_input_map :: proc(ctx: ^Context, imap: InputMap) -> bool {
    if e, ok := find_key_map_entry_by_rune(ctx,imap.up); ok {
        ctx.trackingState[0] = TrackingState{e.keycode, .Up, .Up};
    } else {
        return false;
    }

    if e, ok := find_key_map_entry_by_rune(ctx,imap.down); ok {
        ctx.trackingState[1] = TrackingState{e.keycode, .Down, .Up};
    } else {
        return false;
    }

    if e, ok := find_key_map_entry_by_rune(ctx,imap.left); ok {
        ctx.trackingState[2] = TrackingState{e.keycode, .Left, .Up};
    } else {
        return false;
    }

    if e, ok := find_key_map_entry_by_rune(ctx,imap.right); ok {
        ctx.trackingState[3] = TrackingState{e.keycode, .Right, .Up};
    } else {
        return false;
    }

    if e, ok := find_key_map_entry_by_rune(ctx,imap.select); ok {
        ctx.trackingState[4] = TrackingState{e.keycode, .Select, .Up};
    } else {
        return false;
    }

    if e, ok := find_key_map_entry_by_rune(ctx,imap.exit); ok {
        ctx.trackingState[5] = TrackingState{e.keycode, .Exit, .Up};
    } else {
        return false;
    }

    fmt.printf("trackingState: %v\n", ctx.trackingState);

    return true;
}

close_window :: proc(ctx: ^Context, window: Window) {
    _ = xcb.unmap_window(ctx.conn,window.id);
    _ = xcb.flush(ctx.conn);
}

create_window :: proc(ctx: ^Context) -> (Window, bool) {
    window := Window {
        id = xcb.generate_id(ctx.conn),
    };
    mask := u32(xcb.Cw.EventMask);
    eventMasks := []i32{
        i32(xcb.EventMask.KeyPress |
            xcb.EventMask.KeyRelease |
            xcb.EventMask.ButtonPress |
            xcb.EventMask.ButtonRelease |
            xcb.EventMask.PointerMotion |
            xcb.EventMask.Exposure |
            xcb.EventMask.VisibilityChange |
            xcb.EventMask.FocusChange |
            xcb.EventMask.ResizeRedirect)
    };
    _ = xcb.create_window(
        c = ctx.conn,
        depth = xcb.COPY_FROM_PARENT,
        wid = window.id,
        parent = ctx.screen^.root,
        x = 100,
        y = 100,
        width = 521,
        height = 521,
        borderWidth = 10,
        class = u16(xcb.WindowClass.InputOutput),
        visual = ctx.screen^.rootVisual,
        valueMask = mask,
        valueList = mem.raw_slice_data(eventMasks)
    );

    _ = xcb.map_window(ctx.conn, window.id);
    _ = xcb.flush(ctx.conn);
    return window, true;
}


disconnect_display :: proc(ctx: ^Context) {
    xcb.disconnect(ctx.conn);
}

wait_for_event :: proc(ctx: ^Context) -> ^xcb.GenericEvent {
    return xcb.wait_for_event(ctx.conn);
}

poll_for_event :: proc(ctx: ^Context) -> ^xcb.GenericEvent {
    return xcb.poll_for_event(ctx.conn);
}

free_event :: proc(event: ^xcb.GenericEvent) {
    os.heap_free(event);
}

init_keybaord_mapping :: proc(ctx: ^Context) {
    keyboard_mapping := xcb.get_keyboard_mapping_reply(
        ctx.conn,
        xcb.get_keyboard_mapping(
            ctx.conn,
            ctx.setup.minKeycode,
            ctx.setup.maxKeycode - ctx.setup.minKeycode + 1),
        nil);
    defer os.heap_free(keyboard_mapping);

    nkeycodes := keyboard_mapping.length / u32(keyboard_mapping.keysymsPerKeycode);
    nkeysyms  := keyboard_mapping.length;
    keysymsptr  := transmute(^xcb.Keysym)(mem.ptr_offset(keyboard_mapping,1));  // `xcb_keycode_t` is just a `typedef u8`, and `xcb_keysym_t` is just a `typedef u32`
    keysyms := mem.slice_ptr(keysymsptr,int(nkeysyms));

    for keycodeIdx : u32 = 0; keycodeIdx < nkeycodes; keycodeIdx += 1 {
        kk := u32(ctx.setup.minKeycode) + keycodeIdx;
        keysym := keysyms[keycodeIdx * u32(keyboard_mapping.keysymsPerKeycode)];
        if e, ok := find_xk_map_entry(keysym); ok {
            ctx.keyMap[keycodeIdx] = KeymapEntry{xcb.Keycode(kk), e.xk, e.char};
        }
    }

    // fmt.printf("keymap: %v\n", ctx.keyMap);
}

update_tracking_state :: proc(ctx: ^Context, keycode: xcb.Keycode, upDown: input.KeyUpDown) {
    for _, i in ctx.trackingState {
        if ctx.trackingState[i].keycode == keycode {
            ctx.trackingState[i].upDown = upDown;
            break;
        }
    }
}

update_key_state :: proc(ctx: ^Context, uiState: ^input.UIState) {
    for _, i in ctx.trackingState {
        if ctx.trackingState[i].upDown != uiState.keys[i].upDown {
            uiState.keys[i].changed = true;
        }
        uiState.keys[i].upDown = ctx.trackingState[i].upDown;
    }
}

show_keyboard_mapping :: proc(ctx: ^Context) {
    keyboard_mapping := xcb.get_keyboard_mapping_reply(
        ctx.conn,
        xcb.get_keyboard_mapping(
            ctx.conn,
            ctx.setup.minKeycode,
            ctx.setup.maxKeycode - ctx.setup.minKeycode + 1),
        nil);
    defer os.heap_free(keyboard_mapping);

    nkeycodes := keyboard_mapping.length / u32(keyboard_mapping.keysymsPerKeycode);
    nkeysyms  := keyboard_mapping.length;
    keysymsptr  := transmute(^xcb.Keysym)(mem.ptr_offset(keyboard_mapping,1));  // `xcb_keycode_t` is just a `typedef u8`, and `xcb_keysym_t` is just a `typedef u32`
    keysyms := mem.slice_ptr(keysymsptr,int(nkeysyms));
    fmt.printf("nkeycodes %d  nkeysyms %d  keysyms_per_keycode %d\n\n", nkeycodes, nkeysyms, keyboard_mapping.keysymsPerKeycode);

    for keycode_idx : u32 = 0; keycode_idx < nkeycodes; keycode_idx += 1 {
        fmt.printf("keycode %3d ", u32(ctx.setup.minKeycode) + keycode_idx);
        for keysym_idx : u8 = 0; keysym_idx < keyboard_mapping.keysymsPerKeycode; keysym_idx += 1 {
            fmt.printf(" %8x", keysyms[u32(keysym_idx) + keycode_idx * u32(keyboard_mapping.keysymsPerKeycode)]);
        }
        fmt.println();
    }
}


get_input_state :: proc(ctx: ^Context, uiState: ^input.UIState) -> bool {
    done : ^tsync.Channel(bool);
    done = tsync.channel_make(bool, 1);
    defer tsync.channel_destroy(done);
    {
        failed: bool;
        context.user_ptr = &failed;
        panicHandler :: proc(prefix, message: string, loc: runtime.Source_Code_Location) {
            target := transmute(^bool)(context.user_ptr);
            target^ = false;
        }
        context.assertion_failure_proc = panicHandler;
        tsync.channel_send(ctx.getInputChannel,GetInputRequest{uiState,done});
        if failed {
            return false;
        }
    }
    for _, ok := tsync.channel_try_receive(done); !ok; _, ok = tsync.channel_try_receive(done) {
        time.nanosleep(1000000);
    }
    return true;
}

shutdown :: proc(ctx: ^Context, window: Window) {
    log.info(".... shutting down ...");
    cleanup :: proc(ctx: ^Context) {
        tsync.channel_destroy(&ctx.xcbChannel);
        tsync.channel_destroy(&ctx.getInputChannel);
    }

    defer cleanup(ctx);

    close_window(ctx,window);
    tsync.wait_group_wait(&ctx.xcbWaitGroup);
    tsync.wait_group_wait(&ctx.uiWaitGroup);
    log.info(".... shutting down ... done");
}

poll_input_loop :: proc(ctx: ^Context) {
    cleanup :: proc(ctx: ^Context) {
        tsync.channel_close(&ctx.getInputChannel);
        tsync.wait_group_done(&ctx.uiWaitGroup);
    }

    defer cleanup(ctx);

    selectChannels := []tsync.Select_Channel {
        {
            ctx.getInputChannel._internal,
                .Recv,
        },
        {
            ctx.xcbChannel._internal,
                .Recv
        },
    };

    for {
        idx := tsync.select(..selectChannels);
        // log.infof("idx: %v", idx);
        switch idx {
        case -1:
            time.nanosleep(1000000);
        case 0:
            m := tsync.channel_recv(&ctx.getInputChannel);
            // log.infof("m: %v", m);
            input.prep_keys_for_scan(m.uiState);
            // log.info("input.prep_keys_for_scan(m.uiState)");
            update_key_state(ctx, m.uiState);
            // log.info("update_key_state(ctx, m.uiState)");
            tsync.channel_send(m.done, true);
            // log.info("done");
        case 1:
            m := tsync.channel_recv(&ctx.xcbChannel);
            switch v in m {
            case bool:
                break;
            case xcb.GenericEvent:
                vc := v;
                event := &vc;
                // log.infof("got GenericEvent: %v", vc);
                evt := event.responseType & eventMask;
                switch evt {
                case xcb.KEY_PRESS:
                    kr := transmute(^xcb.KeyPressEvent)event;
                    update_tracking_state(ctx,kr.detail,input.KeyUpDown.Down);
                    // fmt.println("xcb.KEY_PRESS");
                case xcb.KEY_RELEASE:
                    kr := transmute(^xcb.KeyReleaseEvent)event;
                    update_tracking_state(ctx,kr.detail,input.KeyUpDown.Up);
                    // fmt.println("xcb.KEY_RELEASE");
                case xcb.BUTTON_PRESS:
                    fmt.println("xcb.BUTTON_PRESS");
                case xcb.BUTTON_RELEASE:
                    fmt.println("xcb.BUTTON_RELEASE");
                case xcb.MOTION_NOTIFY:
                    fmt.println("xcb.MOTION_NOTIFY");
                case xcb.ENTER_NOTIFY:
                    fmt.println("xcb.ENTER_NOTIFY");
                case xcb.LEAVE_NOTIFY:
                    fmt.println("xcb.LEAVE_NOTIFY");
                case xcb.FOCUS_IN:
                    fmt.println("xcb.FOCUS_IN");
                case xcb.FOCUS_OUT:
                    fmt.println("xcb.FOCUS_OUT");
                case xcb.KEYMAP_NOTIFY:
                    fmt.println("xcb.KEYMAP_NOTIFY");
                case xcb.EXPOSE:
                    fmt.println("xcb.EXPOSE");
                case xcb.GRAPHICS_EXPOSURE:
                    fmt.println("xcb.GRAPHICS_EXPOSURE");
                case xcb.NO_EXPOSURE:
                    fmt.println("xcb.NO_EXPOSURE");
                case xcb.RESIZE_REQUEST:
                    fmt.println("xcb.RESIZE_REQUEST");
                case xcb.VISIBILITY_NOTIFY:
                    fmt.println("xcb.VISIBILITY_NOTIFY");
                case :
                    fmt.printf("Got unexpected event type: %d\n", evt);
                }
            }
        }
    }
}


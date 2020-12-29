package input

Key :: enum u8 {
  Up,
  Down,
  Left,
  Right,
  Select,
  Exit,
  LAST,
}

KeyUpDown :: enum u8 {
  Up,
  Down,
}

KeyState :: struct {
  key: Key,
  upDown: KeyUpDown,
  changed: bool,
}

MouseState :: struct {
  buttonDown: bool,
  x: i32,
  y: i32,
}

UIState :: struct {
  keys: [int(Key.LAST)]KeyState,
  mouse: MouseState,
  inFocus: bool,
}

should_exit :: proc(uiState: ^UIState) -> bool {
  return uiState.keys[int(Key.Exit)].upDown == .Down;
}

init :: proc(uiState: ^UIState) {
  for i : u8 = 0; i < u8(Key.LAST); i += 1 {
    uiState.keys[i] = {
      key = Key(i),
      upDown = .Up,
      changed = false,
    };
  }
  uiState.mouse.buttonDown = false;
}

prep_keys_for_scan :: proc(uiState: ^UIState) {
  for i : u8 = 0; i < u8(Key.LAST); i += 1 {
    uiState.keys[i].changed = false;
  }
}

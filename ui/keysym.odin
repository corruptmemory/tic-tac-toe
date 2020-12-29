package ui

XK :: enum u32 {
  NONE = 0x0000,  /* U+0020 SPACE */
  Space = 0x0020,  /* U+0020 SPACE */
  Exclam = 0x0021,  /* U+0021 EXCLAMATION MARK */
  QuoteDbl = 0x0022,  /* U+0022 QUOTATION MARK */
  NumberSign = 0x0023,  /* U+0023 NUMBER SIGN */
  Dollar = 0x0024,  /* U+0024 DOLLAR SIGN */
  Percent = 0x0025,  /* U+0025 PERCENT SIGN */
  Ampersand = 0x0026,  /* U+0026 AMPERSAND */
  Apostrophe = 0x0027,  /* U+0027 APOSTROPHE */
  QuoteRight = 0x0027,  /* deprecated */
  ParenLeft = 0x0028,  /* U+0028 LEFT PARENTHESIS */
  ParenRight = 0x0029,  /* U+0029 RIGHT PARENTHESIS */
  Asterisk = 0x002a,  /* U+002A ASTERISK */
  Plus = 0x002b,  /* U+002B PLUS SIGN */
  Comma = 0x002c,  /* U+002C COMMA */
  Minus = 0x002d,  /* U+002D HYPHEN-MINUS */
  Period = 0x002e,  /* U+002E FULL STOP */
  Slash = 0x002f,  /* U+002F SOLIDUS */
  _0 = 0x0030,  /* U+0030 DIGIT ZERO */
  _1 = 0x0031,  /* U+0031 DIGIT ONE */
  _2 = 0x0032,  /* U+0032 DIGIT TWO */
  _3 = 0x0033,  /* U+0033 DIGIT THREE */
  _4 = 0x0034,  /* U+0034 DIGIT FOUR */
  _5 = 0x0035,  /* U+0035 DIGIT FIVE */
  _6 = 0x0036,  /* U+0036 DIGIT SIX */
  _7 = 0x0037,  /* U+0037 DIGIT SEVEN */
  _8 = 0x0038,  /* U+0038 DIGIT EIGHT */
  _9 = 0x0039,  /* U+0039 DIGIT NINE */
  Colon = 0x003a,  /* U+003A COLON */
  Semicolon = 0x003b,  /* U+003B SEMICOLON */
  Less = 0x003c,  /* U+003C LESS-THAN SIGN */
  Equal = 0x003d,  /* U+003D EQUALS SIGN */
  Greater = 0x003e,  /* U+003E GREATER-THAN SIGN */
  Question = 0x003f,  /* U+003F QUESTION MARK */
  At = 0x0040,  /* U+0040 COMMERCIAL AT */
  A = 0x0041,  /* U+0041 LATIN CAPITAL LETTER A */
  B = 0x0042,  /* U+0042 LATIN CAPITAL LETTER B */
  C = 0x0043,  /* U+0043 LATIN CAPITAL LETTER C */
  D = 0x0044,  /* U+0044 LATIN CAPITAL LETTER D */
  E = 0x0045,  /* U+0045 LATIN CAPITAL LETTER E */
  F = 0x0046,  /* U+0046 LATIN CAPITAL LETTER F */
  G = 0x0047,  /* U+0047 LATIN CAPITAL LETTER G */
  H = 0x0048,  /* U+0048 LATIN CAPITAL LETTER H */
  I = 0x0049,  /* U+0049 LATIN CAPITAL LETTER I */
  J = 0x004a,  /* U+004A LATIN CAPITAL LETTER J */
  K = 0x004b,  /* U+004B LATIN CAPITAL LETTER K */
  L = 0x004c,  /* U+004C LATIN CAPITAL LETTER L */
  M = 0x004d,  /* U+004D LATIN CAPITAL LETTER M */
  N = 0x004e,  /* U+004E LATIN CAPITAL LETTER N */
  O = 0x004f,  /* U+004F LATIN CAPITAL LETTER O */
  P = 0x0050,  /* U+0050 LATIN CAPITAL LETTER P */
  Q = 0x0051,  /* U+0051 LATIN CAPITAL LETTER Q */
  R = 0x0052,  /* U+0052 LATIN CAPITAL LETTER R */
  S = 0x0053,  /* U+0053 LATIN CAPITAL LETTER S */
  T = 0x0054,  /* U+0054 LATIN CAPITAL LETTER T */
  U = 0x0055,  /* U+0055 LATIN CAPITAL LETTER U */
  V = 0x0056,  /* U+0056 LATIN CAPITAL LETTER V */
  W = 0x0057,  /* U+0057 LATIN CAPITAL LETTER W */
  X = 0x0058,  /* U+0058 LATIN CAPITAL LETTER X */
  Y = 0x0059,  /* U+0059 LATIN CAPITAL LETTER Y */
  Z = 0x005a,  /* U+005A LATIN CAPITAL LETTER Z */
  BracketLeft = 0x005b,  /* U+005B LEFT SQUARE BRACKET */
  Backslash = 0x005c,  /* U+005C REVERSE SOLIDUS */
  BracketRight = 0x005d,  /* U+005D RIGHT SQUARE BRACKET */
  Asciicircum = 0x005e,  /* U+005E CIRCUMFLEX ACCENT */
  Underscore = 0x005f,  /* U+005F LOW LINE */
  Grave = 0x0060,  /* U+0060 GRAVE ACCENT */
  QuoteLeft = 0x0060,  /* deprecated */
  a = 0x0061,  /* U+0061 LATIN SMALL LETTER A */
  b = 0x0062,  /* U+0062 LATIN SMALL LETTER B */
  c = 0x0063,  /* U+0063 LATIN SMALL LETTER C */
  d = 0x0064,  /* U+0064 LATIN SMALL LETTER D */
  e = 0x0065,  /* U+0065 LATIN SMALL LETTER E */
  f = 0x0066,  /* U+0066 LATIN SMALL LETTER F */
  g = 0x0067,  /* U+0067 LATIN SMALL LETTER G */
  h = 0x0068,  /* U+0068 LATIN SMALL LETTER H */
  i = 0x0069,  /* U+0069 LATIN SMALL LETTER I */
  j = 0x006a,  /* U+006A LATIN SMALL LETTER J */
  k = 0x006b,  /* U+006B LATIN SMALL LETTER K */
  l = 0x006c,  /* U+006C LATIN SMALL LETTER L */
  m = 0x006d,  /* U+006D LATIN SMALL LETTER M */
  n = 0x006e,  /* U+006E LATIN SMALL LETTER N */
  o = 0x006f,  /* U+006F LATIN SMALL LETTER O */
  p = 0x0070,  /* U+0070 LATIN SMALL LETTER P */
  q = 0x0071,  /* U+0071 LATIN SMALL LETTER Q */
  r = 0x0072,  /* U+0072 LATIN SMALL LETTER R */
  s = 0x0073,  /* U+0073 LATIN SMALL LETTER S */
  t = 0x0074,  /* U+0074 LATIN SMALL LETTER T */
  u = 0x0075,  /* U+0075 LATIN SMALL LETTER U */
  v = 0x0076,  /* U+0076 LATIN SMALL LETTER V */
  w = 0x0077,  /* U+0077 LATIN SMALL LETTER W */
  x = 0x0078,  /* U+0078 LATIN SMALL LETTER X */
  y = 0x0079,  /* U+0079 LATIN SMALL LETTER Y */
  z = 0x007a,  /* U+007A LATIN SMALL LETTER Z */
  BraceLeft = 0x007b,  /* U+007B LEFT CURLY BRACKET */
  Bar = 0x007c,  /* U+007C VERTICAL LINE */
  BraceRight = 0x007d,  /* U+007D RIGHT CURLY BRACKET */
  Tilde = 0x007e,  /* U+007E TILDE */
  BackSpace = 0xff08,  /* Back space, back char */
  Tab = 0xff09,
  Linefeed = 0xff0a,  /* Linefeed, LF */
  Clear = 0xff0b,
  Return = 0xff0d,  /* Return, enter */
  Pause = 0xff13,  /* Pause, hold */
  ScrollLock = 0xff14,
  SysReq = 0xff15,
  Escape = 0xff1b,
  Delete = 0xffff,  /* Delete, rubout */
}

XKCharMapEntry :: struct {
  xk: XK,
  char: rune,
}


XKCharMap :: []XKCharMapEntry {
  { XK.Space, ' ' },
  { XK.Exclam, '!' },
  { XK.QuoteDbl, '"' },
  { XK.NumberSign, '#' },
  { XK.Dollar, '$' },
  { XK.Percent, '%' },
  { XK.Ampersand, '&' },
  { XK.Apostrophe, '\'' },
  { XK.QuoteRight, '"' },
  { XK.ParenLeft, '"' },
  { XK.ParenRight, ')' },
  { XK.Asterisk, '*' },
  { XK.Plus, '+' },
  { XK.Comma, ',' },
  { XK.Minus, '-' },
  { XK.Period, '.' },
  { XK.Slash, '/' },
  { XK._0, '0' },
  { XK._1, '1' },
  { XK._2, '2' },
  { XK._3, '3' },
  { XK._4, '4' },
  { XK._5, '5' },
  { XK._6, '6' },
  { XK._7, '7' },
  { XK._8, '8' },
  { XK._9, '9' },
  { XK.Colon, ':' },
  { XK.Semicolon, ';' },
  { XK.Less, '<' },
  { XK.Equal, '=' },
  { XK.Greater, '>' },
  { XK.Question, '?' },
  { XK.At, '@' },
  { XK.A, 'A' },
  { XK.B, 'B' },
  { XK.C, 'C' },
  { XK.D, 'D' },
  { XK.E, 'E' },
  { XK.F, 'F' },
  { XK.G, 'G' },
  { XK.H, 'H' },
  { XK.I, 'I' },
  { XK.J, 'J' },
  { XK.K, 'K' },
  { XK.L, 'L' },
  { XK.M, 'M' },
  { XK.N, 'N' },
  { XK.O, 'O' },
  { XK.P, 'P' },
  { XK.Q, 'Q' },
  { XK.R, 'R' },
  { XK.S, 'S' },
  { XK.T, 'T' },
  { XK.U, 'U' },
  { XK.V, 'V' },
  { XK.W, 'W' },
  { XK.X, 'X' },
  { XK.Y, 'Y' },
  { XK.Z, 'Z' },
  { XK.BracketLeft, '[' },
  { XK.Backslash, '\\' },
  { XK.BracketRight, ']' },
  { XK.Asciicircum, '^' },
  { XK.Underscore, '_' },
  { XK.Grave, '`' },
  { XK.QuoteLeft, '"' },
  { XK.a, 'a' },
  { XK.b, 'b' },
  { XK.c, 'c' },
  { XK.d, 'd' },
  { XK.e, 'e' },
  { XK.f, 'f' },
  { XK.g, 'g' },
  { XK.h, 'h' },
  { XK.i, 'i' },
  { XK.j, 'j' },
  { XK.k, 'k' },
  { XK.l, 'l' },
  { XK.m, 'm' },
  { XK.n, 'n' },
  { XK.o, 'o' },
  { XK.p, 'p' },
  { XK.q, 'q' },
  { XK.r, 'r' },
  { XK.s, 's' },
  { XK.t, 't' },
  { XK.u, 'u' },
  { XK.v, 'v' },
  { XK.w, 'w' },
  { XK.x, 'x' },
  { XK.y, 'y' },
  { XK.z, 'z' },
  { XK.BraceLeft, '{' },
  { XK.Bar, '|' },
  { XK.BraceRight, '}' },
  { XK.Tilde, '`' },
  { XK.BackSpace, 0x08 },
  { XK.Tab, 0x09 },
  { XK.Linefeed, 0x10 },
  { XK.Clear, 0x0C },
  { XK.Return, 0x0D },
  { XK.Escape, 0x1B },
  { XK.Delete, 0x7F },
};


find_xk_map_entry :: proc(keysym: u32) -> (XKCharMapEntry, bool) {
  for e, _ in XKCharMap {
    if u32(e.xk) == keysym {
      return e, true;
    }
  }

  return XKCharMapEntry{}, false;
}
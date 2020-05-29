package types is
  type mode_t is new Positive;
  subtype off_t is Positive;
  OPEN_MAX : constant := 20; -- open files a process may have
  type Byte is mod 2**8;
  type buffer is array (Integer range <>) of types.Byte;
end types;

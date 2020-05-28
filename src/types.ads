package types is
  type mode_t is new Positive;
  type off_t is new Positive;
  OPEN_MAX : constant := 20; -- open files a process may have
end types;

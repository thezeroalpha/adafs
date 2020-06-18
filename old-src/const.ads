package const is
  block_size : constant := 1024; -- bytes
  imap_start : constant := 3;
  open_max : constant :=  20;
  nr_filps : constant :=  128;
  nr_procs : constant := 32;
  nr_inodes : constant := 64; -- slots in inode table
end const;

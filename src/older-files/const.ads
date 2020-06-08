package const is
  nr_inodes : constant := 64;
  nr_filps : constant :=  128;
  nr_procs : constant := 32;
  block_size : constant := 1024;
  n_indirects : constant := block_size/Positive'Size;
end const;

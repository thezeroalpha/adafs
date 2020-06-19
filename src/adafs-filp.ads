package adafs.filp
  with SPARK_Mode
is
  nr_filps : constant :=  128;
  open_max : constant :=  20;
  type entry_t is record
    count : Natural; -- how many file descriptors share this slot?
    ino : Natural; -- inode number
    pos : Natural; -- file position
  end record;

  subtype tab_num_t is Natural range 0..nr_filps;
  type tab_t is array (1..tab_num_t'Last) of entry_t;

  subtype fd_t is Natural range 0..open_max;
  type open_tab_t is array (1..fd_t'Last) of tab_num_t;

  null_fd : constant fd_t := 0;
  no_filp : constant tab_num_t := 0;
  tab : tab_t := (others => (count => 0, ino => 0, pos => 1));

  function get_free_fd (open_filps : open_tab_t) return fd_t with
    Depends => (get_free_fd'Result => open_filps),
    Post => (if (for all f of open_filps => f /= null_fd)
             then get_free_fd'Result = null_fd
              else get_free_fd'Result in open_tab_t'Range);

  procedure get_free_filp (free_fd : out tab_num_t) with
    Global => (in_out => tab),
    Depends => (free_fd => tab, tab => tab),
    Post => (if (for all f of tab'Old => f.count /= 0)
             then free_fd = no_filp);
end adafs.filp;

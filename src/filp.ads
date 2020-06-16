with const;
package filp is
  type entry_t is record
    count : Natural; -- how many file descriptors share this slot?
    ino : Natural; -- inode number
    pos : Natural; -- file position
  end record;

  subtype tab_num_t is Natural range 0..const.nr_filps;
  type tab_t is array (1..tab_num_t'Last) of entry_t;

  subtype fd_t is Natural range 0..const.open_max;
  type open_tab_t is array (1..fd_t'Last) of tab_num_t;

  null_fd : fd_t := 0;
  no_filp : tab_num_t := 0;
  tab : tab_t := (others => (count => 0, ino => 0, pos => 1));

  function get_free_fd (open_filps : open_tab_t) return fd_t;
  function get_free_filp return tab_num_t;
end filp;



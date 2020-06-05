-- This is the filp table.  It is an intermediary between file descriptors and
-- inodes.  A slot is free if filp_count == 0.
with types;
with inode;
with const;
package filp is
  FILP_CLOSED : constant := 0;
  type null_record is null record;
  NIL_FILP : null_record;

  type filp is record
    filp_count : Positive;      -- how many file descriptors share this slot?
    filp_ino : inode.num;       -- inode number
    filp_pos : types.off_t;    -- file position
  end record;

  type tab_t is array (1..const.nr_filps) of filp;
  subtype num is Integer range 1..const.nr_filps;
  tables : array (1..const.nr_procs) of tab_t; -- can only have as many filps as processes, can have less
  function get_entry (filp_entry_num : num; fd : Positive) return filp;
  procedure update_pos (filp_entry_num : num; fd : Positive; pos : types.off_t);
end filp;

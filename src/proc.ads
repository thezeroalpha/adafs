-- the process table, indexed by PID
with Ada.Text_IO;
with const, filp;
package proc is
  package tio renames Ada.Text_IO;
  type entry_t (is_null : Boolean := False) is record
    case is_null is
      when True => null;
      when False =>
        workdir : Natural;    -- pointer to working directory's inode
        rootdir : Natural;    -- pointer to current root dir (see chroot)
        open_filps : filp.open_tab_t;    -- index into the filp table, multiple procs can point to same one
    end case;
  end record;

  subtype tab_range is Positive range 1..const.nr_procs;
  type tab_t is array (tab_range) of entry_t;

  tab : tab_t := (
    others => (
      is_null => False,
      workdir => 1,
      rootdir => 1,
      open_filps => (others => filp.null_fd)));

  function get_entry (pid : tab_range) return entry_t is (tab(pid));
  procedure put_entry (pid : tab_range; procentry : entry_t);
end proc;

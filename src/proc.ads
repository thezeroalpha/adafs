-- the process table, indexed by PID
with const;
with Ada.Text_IO;
package proc is
  package tio renames Ada.Text_IO;
  type entry_t (is_null : Boolean := False) is record
    case is_null is
      when True => null;
      when False =>
        workdir : Natural;    -- pointer to working directory's inode
        rootdir : Natural;    -- pointer to current root dir (see chroot)
        filp_tab_num : Natural;    -- index into the filp table, multiple procs can point to same one
    end case;
  end record;
  subtype tab_range is Positive range 1..const.nr_procs;
  type tab_t is array (tab_range) of entry_t;

  nil_entry : entry_t := (is_null => True);
  tab : tab_t := (others => nil_entry);

  function get_entry (pid : tab_range) return entry_t is (tab(pid));
  procedure new_entry (pid : tab_range);
end proc;

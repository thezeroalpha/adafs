-- the process table, indexed by PID
with Ada.Text_IO;
with adafs.filp;
package adafs.proc
  with SPARK_Mode
is
  package tio renames Ada.Text_IO;

  nr_procs : constant := 32;
  type entry_t (is_null : Boolean := False) is record
    case is_null is
      when True => null;
      when False =>
        workdir : Positive;    -- pointer to working directory's inode
        rootdir : Positive;    -- pointer to current root dir (see chroot)
        open_filps : filp.open_tab_t;    -- index into the filp table, multiple procs can point to same one
    end case;
  end record;

  subtype tab_range is Positive range 1..nr_procs;
  type tab_t is array (tab_range) of entry_t;

  tab : tab_t := (others => (is_null => True));

  procedure init_entry (pid : tab_range) with
    Global => (in_out => tab),
    Pre => tab(pid).is_null,
    Post => (not tab(pid).is_null) and tab(pid).workdir > 0;

  function get_entry (pid : tab_range) return entry_t with
    Global => (input => tab),
    Depends => (get_entry'Result => (tab, pid)),
    Post => (if tab(pid).is_null then get_entry'Result.is_null else get_entry'Result.workdir > 0);

  procedure put_entry (pid : in tab_range; procentry : entry_t) with
    Pre => (not procentry.is_null),
    Post => tab(pid) = procentry;
end adafs.proc;

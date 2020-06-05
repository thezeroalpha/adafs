with filp;
with inode;
with const;
package proc is
  type fproc is record
    workdir : inode.num;    -- pointer to working directory's inode
    rootdir : inode.num;    -- pointer to current root dir (see chroot)
    filp_tab : filp.num;    -- index into the filp table, multiple procs can point to same one
    pid : Positive;         -- PID of the process associated with the entry
  end record;

  type tab_t is array (1..const.nr_procs) of fproc;
  tab : tab_t;

  function get_entry (pid : Positive) return fproc;
end proc;

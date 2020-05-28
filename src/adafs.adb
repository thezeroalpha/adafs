with proc;
with filp;
with inode;
with System.Storage_Elements;
package body AdaFS is
  function Read (fd : Positive; buffer : System.Storage_Elements.Storage_Element; nbytes : Positive; pid : Positive) return Integer is
    -- use pid to find fdtable
    proc_entry : proc.fproc := proc.get_entry (pid);
    -- use fd to index into found fdtable and find inode
    filp_entry : filp.filp := filp.get_entry (proc_entry.filp_tab, fd);
    f_inode : inode.inode := inode.get_entry (filp_entry.filp_ino);
  begin
    -- break up request to fit into blocks (1024 bytes each)
    -- copy to appropriate place in user buffer
    -- return number of bytes copied
    return 42;
  end Read;
end AdaFS;

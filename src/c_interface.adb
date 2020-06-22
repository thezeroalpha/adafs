package body c_interface is
  function ada_getattr(path : cstrings.chars_ptr; pid : c.int) return fuse_attrs_t is
    path_str : String := cstrings.value(path);
    pid_int : Integer := Integer(pid);
    attrs : adafs.inode.attrs_t := fs.getattr(path_str, pid_int);
  begin
    return (c.int(attrs.size), c.int(attrs.nlinks));
  end ada_getattr;

  procedure fsinit is begin
    fs.init;
  end fsinit;

  procedure fsdeinit is begin
    fs.deinit;
  end fsdeinit;
end c_interface;

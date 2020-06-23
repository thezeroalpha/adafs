package body c_interface is
  function ada_getattr(path : cstrings.chars_ptr; pid : c.int) return fuse_attrs_t is
    path_str : String := cstrings.value(path);
    pid_int : Integer := Integer(pid);
    attrs : adafs.inode.attrs_t := fs.getattr(path_str, pid_int);
  begin
    return (c.int(attrs.size), c.int(attrs.nlinks));
  end ada_getattr;

  procedure ada_readdir(path : cstrings.chars_ptr; fuse_contents : in out cstrings.chars_ptr_array; size : Natural; pid : c.int) is
    dir_contents : adafs.dir_buf_t := fs.readdir(cstrings.value(path), Integer(pid));
  begin
    for i in dir_contents'Range loop
      fuse_contents(c.size_t(i-1)) := cstrings.New_String(dir_contents(i));
    end loop;
  end ada_readdir;

  procedure fsinit is begin
    fs.init;
  end fsinit;

  procedure fsdeinit is begin
    fs.deinit;
  end fsdeinit;

  function ada_create(path : cstrings.chars_ptr; pid : c.int) return c.int is
  begin
    return c.int(fs.create(cstrings.value(path), Integer(pid)));
  end ada_create;

  function ada_open(path : cstrings.chars_ptr; pid : c.int) return c.int is
  begin
    return c.int(fs.open(cstrings.value(path), Integer(pid)));
  end ada_open;

  function ada_read(fd : c.int; nbytes : c.size_t; offset : c.int; buf : cstrings.chars_ptr; pid : c.int) return c.int is
    fs_fd : adafs.filp.fd_t := adafs.filp.fd_t(fd);
    fs_nbytes : Natural := Natural(nbytes);
    fs_pid : Integer := Integer(pid);
    contents : adafs.data_buf_t(1..fs_nbytes);
    new_file_offset : Natural;
  begin
    new_file_offset := fs.lseek(fs_fd, Integer(offset)+1, fs.SEEK_SET, fs_pid);
    contents := fs.read(fs_fd, fs_nbytes, fs_pid);
    cstrings.update(buf, 0, String(contents), False);
    return c.int(contents'Length);
  end ada_read;

end c_interface;

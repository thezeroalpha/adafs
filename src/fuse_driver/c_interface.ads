with adafs.operations, adafs.filp, disk, adafs.inode;
with Interfaces.C.Strings;
package c_interface is
  package fs renames adafs.operations;
  package cstrings renames Interfaces.C.Strings;
  package c renames Interfaces.C;

  type fuse_attrs_t is record
    size : c.int;
    nlinks : c.int;
  end record with Convention => C;

  procedure fsinit with
    Export => True,
    Convention => C,
    External_Name => "ada_fsinit";

  procedure fsdeinit with
    Export => True,
    Convention => C,
    External_Name => "ada_fsdeinit";

  function ada_getattr(path : cstrings.chars_ptr; pid : c.int) return fuse_attrs_t with
    Export => True,
    Convention => C,
    External_Name => "ada_getattr";

  procedure ada_readdir(path : cstrings.chars_ptr; fuse_contents : in out cstrings.chars_ptr_array; size : Natural; pid : c.int) with
    Export => True,
    Convention => C,
    External_Name => "ada_readdir";

  function ada_create(path : cstrings.chars_ptr; pid : c.int) return c.int with
    Export => True,
    Convention => C,
    External_Name => "ada_create";

  function ada_open(path : cstrings.chars_ptr; pid : c.int) return c.int with
    Export => True,
    Convention => C,
    External_Name => "ada_open";

  procedure ada_close(fd : c.int; pid : c.int) with
    Export => True,
    Convention => C,
    External_Name => "ada_close";

  function ada_read(fd : c.int; nbytes : c.size_t; offset : c.int; buf : cstrings.chars_ptr; pid : c.int) return c.int with
    Export => True,
    Convention => C,
    External_Name => "ada_read";

  function ada_write(fd : c.int; nbytes : c.size_t; offset : c.int; buf : cstrings.chars_ptr; pid : c.int) return c.int with
    Export => True,
    Convention => C,
    External_Name => "ada_write";

  procedure ada_unlink(path : cstrings.chars_ptr; pid, isdir : c.int) with
    Export => True,
    Convention => C,
    External_Name => "ada_unlink";

end c_interface;

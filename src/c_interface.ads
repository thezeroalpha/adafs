with adafs.operations, disk, adafs.inode;
with Interfaces.C.Strings;
package c_interface is
  package dsk is new disk("/home/zeroalpha/bsc/adafs/disk.img");
  package fs is new adafs.operations(dsk);
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
end c_interface;

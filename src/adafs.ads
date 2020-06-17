with disk, superblock, bitmap, const, proc, filp, disk.inode;
package adafs is
  package dsk is new disk ("disk.img");
  super : superblock.superblock_t;
  package inode is new dsk.inode (super);
  procedure init;
  procedure deinit;

  subtype fd_t is Natural;
  function open (path : String; pid : proc.tab_range) return fd_t;
  function create (path : String; pid : proc.tab_range) return fd_t;
  function write (fd : fd_t; num_bytes : Natural; data : dsk.data_buf_t; pid : proc.tab_range) return Natural;
  function read (fd : fd_t; num_bytes : Natural; pid : proc.tab_range) return dsk.data_buf_t;
  type seek_whence_t is (SEEK_SET, SEEK_CUR, SEEK_END);
  function lseek (fd : fd_t; offset : Integer; whence : seek_whence_t; pid : proc.tab_range) return Natural;
  procedure close (fd : fd_t; pid : proc.tab_range);
end adafs;

with Ada.Text_IO;
with disk;
with disk.inode;
with adafs.proc;
with adafs.filp;
with adafs.inode;
generic
  with package dsk is new disk (<>);
package adafs.operations is
  package inode is new dsk.inode;
  package tio renames Ada.Text_IO;
  procedure init;
  procedure deinit;
  function open (path : String; pid : adafs.proc.tab_range) return adafs.filp.fd_t;
  procedure close (fd : adafs.filp.fd_t; pid : adafs.proc.tab_range);
  function create (path : String; pid : adafs.proc.tab_range) return adafs.filp.fd_t;
  function write (fd : adafs.filp.fd_t; num_bytes : Natural; data : adafs.data_buf_t; pid : adafs.proc.tab_range) return Natural;
  function read (fd : adafs.filp.fd_t; num_bytes : Natural; pid : adafs.proc.tab_range) return adafs.data_buf_t;
  function readdir (fd : adafs.filp.fd_t; pid : adafs.proc.tab_range) return adafs.dir_buf_t;

  type seek_whence_t is (SEEK_SET, SEEK_CUR, SEEK_END);
  function lseek (fd : adafs.filp.fd_t; offset : Integer; whence : seek_whence_t; pid : adafs.proc.tab_range) return Natural;
end adafs.operations;

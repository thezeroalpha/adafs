with Ada.Text_IO;
with disk;
with disk.inode;
with adafs.proc;
with adafs.filp;
with adafs.inode;
package adafs.operations is
  package tio renames Ada.Text_IO;
  procedure init;
  procedure deinit;
  function open (path : String; pid : adafs.proc.tab_range) return adafs.filp.fd_t;
  procedure close (fd : adafs.filp.fd_t; pid : adafs.proc.tab_range);
  function create (path : String; pid : adafs.proc.tab_range) return adafs.filp.fd_t;
  procedure unlink (path : String; pid : adafs.proc.tab_range; isdir : Boolean := False);
  function write (fd : adafs.filp.fd_t; num_bytes : Natural; data : adafs.data_buf_t; pid : adafs.proc.tab_range) return Natural;
  function read (fd : adafs.filp.fd_t; num_bytes : Natural; pid : adafs.proc.tab_range) return adafs.data_buf_t;
  function readdir (path : String; pid : adafs.proc.tab_range) return adafs.dir_buf_t;
  function getattr (path : String; pid : adafs.proc.tab_range) return adafs.inode.attrs_t;

  type seek_whence_t is (SEEK_SET, SEEK_CUR, SEEK_END);
  function lseek (fd : adafs.filp.fd_t; offset : Integer; whence : seek_whence_t; pid : adafs.proc.tab_range) return Natural;
end adafs.operations;

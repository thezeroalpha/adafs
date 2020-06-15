with disk, superblock, bitmap, const, proc, filp, disk.inode;
package adafs is
  package dsk is new disk ("disk.img");
  super : superblock.superblock_t;
  package inode is new dsk.inode (super);
  procedure init;

  subtype fd_t is Natural;
  function open (path : String; pid : proc.tab_range) return fd_t;
  function create (path : String; pid : proc.tab_range) return fd_t;
end adafs;

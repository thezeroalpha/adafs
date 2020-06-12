with disk;
with superblock;
with bitmap;
with const;
with proc;
package adafs is
  package dsk is new disk ("disk.img");
  super : superblock.superblock_t;
  procedure init;

  subtype fd_t is Natural;
  function open (path : String; pid : proc.tab_range) return fd_t;
end adafs;

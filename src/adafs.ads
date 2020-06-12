with disk, superblock, bitmap, const, proc, filp;
package adafs is
  package dsk is new disk ("disk.img");
  super : superblock.superblock_t;
  procedure init;

  subtype fd_t is Natural;
  function open (path : String; pid : proc.tab_range) return fd_t;
end adafs;

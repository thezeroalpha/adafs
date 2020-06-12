with disk;
with superblock;
with bitmap;
with const;
package adafs is
  package dsk is new disk ("disk.img");
  super : superblock.superblock_t;
  procedure init;
end adafs;

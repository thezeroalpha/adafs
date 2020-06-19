with disk;
generic
  with package dsk is new disk (<>);
package adafs.operations
  with SPARK_Mode
is
  function open return Natural is (dsk.get_disk.super.n_inodes);
end adafs.operations;

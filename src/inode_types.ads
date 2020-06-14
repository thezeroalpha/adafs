with const;
package inode_types is
  n_total_zones : constant := 10; -- total zone numbers in inode
  type zone_array is array (1..n_total_zones) of Positive;
  type on_disk is record
    size : Natural; -- file size in bytes
    zone : zone_array;
    nlinks : Natural;
  end record;

  inode_size : Natural := on_disk'Size;
  num_per_block : Natural := const.block_size/inode_size;
  function calc_num_inodes_for_blocks (nblocks : Natural) return Natural;
end inode_types;

package adafs.inode is
  n_total_zones : constant := 10; -- total zone numbers in inode
  type zone_array is array (1..n_total_zones) of Natural;
  type on_disk is record
    size : Natural; -- file size in bytes
    zone : zone_array;
    nlinks : Natural;
  end record;

  inode_size : Natural := on_disk'Size;
  num_per_block : Natural := block_size/inode_size;
  function calc_num_inodes_for_blocks (nblocks : Natural) return Natural;
end adafs.inode;

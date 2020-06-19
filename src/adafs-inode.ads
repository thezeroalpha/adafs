package adafs.inode
  with SPARK_Mode
is
  n_total_zones : constant := 10; -- total zone numbers in inode
  type zone_array is array (1..n_total_zones) of Natural;
  type on_disk is record
    size : Natural; -- file size in bytes
    zone : zone_array;
    nlinks : Natural;
  end record
    with Size => (4*2+n_total_zones*4)*8;

  inode_size : Positive := on_disk'Size;
  num_per_block : Natural range 1..block_size := block_size/inode_size;
  function calc_num_inodes_for_blocks (nblocks : Natural) return Natural
    with Global => (input => num_per_block),
         Depends => (calc_num_inodes_for_blocks'Result => (nblocks, num_per_block)),
         Pre => nblocks in Natural'Range,
         Post => (calc_num_inodes_for_blocks'Result >= 0) and (calc_num_inodes_for_blocks'Result <= 65535);


end adafs.inode;

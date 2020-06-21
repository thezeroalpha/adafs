package adafs.inode
  with SPARK_Mode
is
  n_total_zones : constant := 10; -- total zone numbers in inode
  zone_size : Positive := 1; -- zone shift is 0
  n_direct_zones : constant := 7;
  nr_inodes : constant := 64; -- slots in inode table
  n_indirects_in_block : constant := block_size/(Natural'Size/8); -- actually 'num zones per indirect block'
  max_file_size : constant := n_direct_zones + n_indirects_in_block + (n_indirects_in_block * n_indirects_in_block);

  type zone_array is array (1..n_total_zones) of Natural;

  -- inode types
  type on_disk is record
    size : Natural; -- file size in bytes
    zone : zone_array;
    nlinks : Natural;
  end record
    with Size => (4*2+n_total_zones*4)*8;

  type in_mem is record
    size : Natural; -- file size in bytes
    zone : zone_array;
    nlinks : Natural;
    -- these are not present on disk:
    num : Natural; -- inode number on its (minor) device
    count : Natural; -- times inode used, if 0 then free
    n_dzones : Natural; -- number of direct zones
    n_indirs : Natural; -- number indirect zones per indirect block
    --  superblock : pointer to superblock -- don't know how to implement this yet
  end record;

  inode_size : Positive := on_disk'Size;
  num_per_block : Natural range 1..block_size := block_size/inode_size;

  -- directory entries
  type direct is record
    inode_num : Natural;
    name : String(1..14); -- 14 == DIRSIZ
  end record;


  -- user data
  subtype data_block_range is Natural range 0..block_size;

  -- block types
  type inode_block_t is array (1..block_size/on_disk'Size) of on_disk;
  type zone_block_t is array (1..n_indirects_in_block) of Natural;
  type dir_entry_block_t is array (1..block_size/direct'Size) of direct;
  subtype data_block_t is data_buf_t (1..data_block_range'Last);

  -- inode table
  subtype tab_num_t is Natural range 0..nr_inodes;
  type tab_t is array (1..tab_num_t'Last) of in_mem;
  nil_inum : Natural := 0;
  no_entry : tab_num_t := 0;
  tab : tab_t;


  function calc_num_inodes_for_blocks (nblocks : Natural) return Natural
    with Global => (input => num_per_block),
         Depends => (calc_num_inodes_for_blocks'Result => (nblocks, num_per_block)),
         Pre => nblocks in Natural'Range,
         Post => (calc_num_inodes_for_blocks'Result >= 0) and (calc_num_inodes_for_blocks'Result <= 65535);

end adafs.inode;

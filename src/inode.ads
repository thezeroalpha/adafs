with const;
package inode is
  n_total_zones : constant := 10; -- total zone numbers in inode
  zone_size : Positive := 1; -- zone shift is 0
  n_direct_zones : constant := 7;
  n_indirects_in_block : constant := const.block_size/(Natural'Size/8);
  max_file_size : constant := n_direct_zones + n_indirects_in_block + (n_indirects_in_block * n_indirects_in_block);

  type zone_array is array (1..n_total_zones) of Positive;
  type on_disk is record
    size : Natural; -- file size in bytes
    zone : zone_array;
    nlinks : Natural;
  end record;
  inode_size : Natural := on_disk'Size;
  num_per_block : Natural := const.block_size/inode_size;
  type inode_block_t is array (1..num_per_block) of on_disk;
  type zone_block_t is array (1..n_indirects_in_block) of Natural;

  type direct is record
    inode_num : Natural;
    name: String(1..14); -- 14 == DIRSIZ
  end record;
  nr_dir_entries : Natural := const.block_size/direct'Size;
  type dir_entry_block is array (1..nr_dir_entries) of direct;

  function calc_num_inodes_for_blocks (nblocks : Natural) return Natural;
end inode;

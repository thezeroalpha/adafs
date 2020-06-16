with const;
with util;
with superblock;
with inode_types; use inode_types;
with proc;
with bitmap;
generic
  super : in out superblock.superblock_t;
package disk.inode is
  procedure set_super (sp : superblock.superblock_t);
  zone_size : Positive := 1; -- zone shift is 0
  n_direct_zones : constant := 7;
  n_indirects_in_block : constant := const.block_size/(Natural'Size/8); -- actually 'num zones per indirect block'
  max_file_size : constant := n_direct_zones + n_indirects_in_block + (n_indirects_in_block * n_indirects_in_block);

  -- inode types
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


  -- directory entries
  type direct is record
    inode_num : Natural;
    name : String(1..14); -- 14 == DIRSIZ
  end record;
  nr_dir_entries : Natural := const.block_size/direct'Size;

  -- user data
  subtype data_block_range is Natural range 0..const.block_size;

  -- block types
  type inode_block_t is array (1..num_per_block) of on_disk;
  type zone_block_t is array (1..n_indirects_in_block) of Natural;
  type dir_entry_block_t is array (1..nr_dir_entries) of direct;
  subtype data_block_t is data_buf_t (1..data_block_range'Last);

  subtype tab_num_t is Natural range 0..const.nr_inodes;
  type tab_t is array (1..tab_num_t'Last) of in_mem;
  nil_inum : Natural := 0;
  no_entry : tab_num_t := 0;
  tab : tab_t;

  subtype name_t is String (1..14); -- limits.h, PATH_MAX
  subtype path_t is String (1..255); -- limits.h, PATH_MAX

  function path_to_inum (path : path_t; procentry : proc.entry_t) return Natural;
  function new_inode (path_str : String; procentry : proc.entry_t) return Natural;
  function get_inode (num : Natural) return in_mem;
  procedure put_inode (ino : in_mem);
  procedure clear_zone (ino : in_mem; pos : Natural);

  procedure write_chunk(ino : in_mem; position, offset_in_blk, chunk, nbytes : Natural; data : data_buf_t);
end disk.inode;

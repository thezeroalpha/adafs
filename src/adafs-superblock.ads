package adafs.superblock
  with SPARK_Mode
is
  pragma Warnings (Off, "*bits of*unused");
  type superblock_t is record
    n_inodes : Natural; -- usable inodes
    zones : Natural; -- total device size including bit maps
    imap_blocks : Natural; -- num blocks used by inode bit map
    zmap_blocks : Natural; -- num blocks used by zone bit map
    first_data_zone : Natural; -- number of first data zone
    log_zone_size : Natural; -- log2( blocks/zone )
    max_size : Natural; -- max file size on the device
    magic : Natural; -- superblock magic number
  end record
    with Size => block_size;
end adafs.superblock;

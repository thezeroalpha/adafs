package adafs is
  block_size : constant := 1024; -- bytes
  bootblock_num : constant := 1;
  superblock_num : constant := 2;
  type data_buf_t is array (Positive range <>) of Character;
end adafs;

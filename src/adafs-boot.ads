package adafs.boot
  with SPARK_Mode
is
  type bootblock_t is array (1..block_size) of Character;
end adafs.boot;

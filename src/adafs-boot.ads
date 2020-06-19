package adafs.boot
  with SPARK_Mode
is
  type bootblock_t is array (1..block_size/4) of String (1..4);
end adafs.boot;

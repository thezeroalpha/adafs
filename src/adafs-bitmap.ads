package adafs.bitmap
  with SPARK_mode
is
  type bitmap_byte_t is mod 2**8 with
    Size => 8, --bits, i.e. 1 byte
    Value_Size => 8;

  type bitmap_block_t is array (1..block_size) of bitmap_byte_t with Pack;
  type bit_t is mod 2;
end adafs.bitmap;

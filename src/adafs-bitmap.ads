package adafs.bitmap
  with SPARK_mode
is
  type bitmap_byte_t is mod 2**8 with
    Size => 8, --bits, i.e. 1 byte
    Value_Size => 8;

  subtype bitmap_block_range is Positive range 1..block_size;
  type bitmap_block_t is array (bitmap_block_range) of bitmap_byte_t with Pack;
  type bit_t is mod 2;
end adafs.bitmap;

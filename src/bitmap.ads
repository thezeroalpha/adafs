with Ada.Streams.Stream_IO;
generic
  bitmap_blocks : Natural;
  start_block : Natural;
  block_size_bytes : Natural;
  disk : access Ada.Streams.Stream_IO.FILE_TYPE;
  disk_acc : access Ada.Streams.Stream_IO.STREAM_ACCESS;
package bitmap is
  package sio renames Ada.Streams.Stream_IO;
  function is_reading return Boolean is (if sio."="(sio.mode(disk.all), sio.in_file) then True else False);
  function is_writing return Boolean is (if sio."="(sio.mode(disk.all), sio.out_file) then True else False);
  type bitmap_byte_t is mod 2**8;
  for bitmap_byte_t'Size use 8;
  for bitmap_byte_t'Value_Size use 8;

  type bitmap_block_t is array (1..block_size_bytes) of bitmap_byte_t with Pack;
  type bitmap_t is array (1..bitmap_blocks) of bitmap_block_t with Pack;
  subtype bit_nums is Integer range 1..bitmap_blocks*block_size_bytes*8;
  type one_bit is mod 2;

  procedure init;
  procedure set_bit (bit_num : bit_nums; value : one_bit);
  function get_bit (bit_num : bit_nums) return one_bit;
  function size_bits return Natural is (bit_nums'Last);
end bitmap;

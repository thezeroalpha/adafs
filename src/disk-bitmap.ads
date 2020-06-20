with Ada.Finalization;
with adafs.bitmap; use adafs.bitmap;
generic
  n_bitmap_blocks : Natural;
  start_block : Natural;
package disk.bitmap
  with SPARK_Mode
is
  pragma Elaborate_Body (disk.bitmap);
  subtype bit_nums is Integer range 1..n_bitmap_blocks*adafs.block_size*8;
  function size_in_bits return Natural is (bit_nums'Last);
  function size_in_blocks return Natural is (n_bitmap_blocks);
  function get_start_block return Natural is (start_block);

  type bitmap_t is array (1..n_bitmap_blocks) of adafs.bitmap.bitmap_block_t with Pack;
  type bitmap_singleton_t is new Ada.Finalization.Controlled with
    record
      bitmap : bitmap_t;
      n_blocks : Natural;
      start_block : Natural;
    end record;
  procedure Initialize (bmp : in out bitmap_singleton_t);
  procedure Finalize (bmp : in out bitmap_singleton_t);
  function get_bitmap return access bitmap_singleton_t;

  procedure clear_bitmap;
  procedure set_bit (bit_num : bit_nums; value : adafs.bitmap.bit_t);
  function get_bit (bit_num : bit_nums) return adafs.bitmap.bit_t;
  function alloc_bit (search_start : bit_nums) return Natural;
end disk.bitmap;

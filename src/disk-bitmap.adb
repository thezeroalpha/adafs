package body disk.bitmap
  with SPARK_Mode
is
  procedure Initialize (bmp : in out bitmap_singleton_t) is
  begin
    bmp.n_blocks := n_bitmap_blocks;
    bmp.start_block := start_block;
    if not is_reading then
      sio.set_mode(stream_io_disk_ft, sio.in_file);
    end if;
    sio.set_index(stream_io_disk_ft, sio.count(((bmp.start_block-1)*1024)+1));
    bitmap_t'read(stream_io_disk_acc, bmp.bitmap);
  end Initialize;


  procedure Finalize (bmp : in out bitmap_singleton_t) is
  begin
    if not is_writing then
      sio.set_mode(stream_io_disk_ft, sio.out_file);
    end if;
    sio.set_index(stream_io_disk_ft, sio.count(((bmp.start_block-1)*1024)+1));
    bitmap_t'write(stream_io_disk_acc, bmp.bitmap);
    sio.flush(stream_io_disk_ft);
  end Finalize;


  bitmap : aliased bitmap_singleton_t;
  function get_bitmap return access bitmap_singleton_t is (bitmap'Access);


  procedure clear_bitmap is
  begin
    bitmap.bitmap := (others => (others => 0));
    if not is_writing then
      sio.set_mode(stream_io_disk_ft, sio.out_file);
    end if;
    sio.set_index(stream_io_disk_ft, sio.count(((bitmap.start_block-1)*1024)+1));
    bitmap_t'write(stream_io_disk_acc, bitmap.bitmap);
    sio.flush(stream_io_disk_ft);
  end clear_bitmap;

  procedure set_bit (bit_num : bit_nums; value : bit_t) is
    bmp_block : Natural := ((bit_num-1)/adafs.block_size)+1;

    byte_location_disk : Natural := Natural((bit_num-1)/8)+1;
    bit_offset : Natural := 8-((bit_num-1) mod 8)-1;
    orig_byte : bitmap_byte_t;
  begin
    -- should not be necessary to read from disk here, but just in case:
    --  if not is_reading then
    --    sio.set_mode(stream_io_disk_ft, sio.in_file);
    --  end if;
    --  sio.set_index(stream_io_disk_ft, sio.count(((start_block-1)*1024)+byte_location_disk));
    --  bitmap_byte_t'read(stream_io_disk_acc, bitmap.bitmap(bmp_block)(bit_num));
    orig_byte := bitmap.bitmap(bmp_block)((((bit_num-1)/8) mod 1024)+1);
    bitmap.bitmap(bmp_block)((((bit_num-1)/8) mod 1024)+1) := (orig_byte and not(2#1# * (2**bit_offset))) or (bitmap_byte_t(value) * 2**(bit_offset));

    if not is_writing then
      sio.set_mode(stream_io_disk_ft, sio.out_file);
    end if;
    sio.set_index(stream_io_disk_ft, sio.count(((start_block-1)*1024)+byte_location_disk));
    bitmap_byte_t'write(stream_io_disk_acc, bitmap.bitmap(bmp_block)((((bit_num-1)/8) mod 1024)+1));
    sio.flush(stream_io_disk_ft);
  end set_bit;

  function get_bit (bit_num : bit_nums) return bit_t is
    bmp_block : Natural := ((bit_num-1)/adafs.block_size)+1;
    byte_location : Natural := Natural((bit_num-1)/8)+1;
    bit_offset : Natural := 8-((bit_num-1) mod 8)-1;

    the_byte : bitmap_byte_t;
    shifted_byte : Natural;
  begin
    -- should not be necessary to read from disk here, but just in case:
    --  if not is_reading then
    --    sio.set_mode(stream_io_disk_ft, sio.in_file);
    --  end if;
    --  sio.set_index(stream_io_disk_ft, sio.count(((start_block-1)*1024)+byte_location));
    --  bitmap_byte_t'read(stream_io_disk_acc, the_byte);
    the_byte := bitmap.bitmap(bmp_block)((((bit_num-1)/8) mod 1024)+1);
    shifted_byte := Natural(the_byte/(2**bit_offset));
    return bit_t(shifted_byte mod 2) and bit_t(2#1#);
  end get_bit;

  function alloc_bit (search_start : bit_nums) return Natural is
  begin
    -- this is gonna be slow..if time allows, try to find a better way
    for i in search_start..bit_nums'Last loop
      if get_bit(i) = 0 then
        set_bit(i, 1);
        return i;
      end if;
    end loop;
    return 0;
  end alloc_bit;
end disk.bitmap;

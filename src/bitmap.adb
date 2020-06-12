package body bitmap is
  procedure init is
    init_map : bitmap_t := (1 => (1 => (1*(2**7) or 0), others => 0), others => (others => 0));
  begin
    if not is_writing then
      sio.set_mode(disk.all, sio.out_file);
    end if;
    sio.set_index(disk.all, sio.count((start_block-1)*1024+1));
    bitmap_t'write(disk_acc.all, init_map);
  end init;

  procedure set_bit (bit_num : bit_nums; value : one_bit) is
    adjusted_bit_num : Natural := bit_num-1;
    byte_location : Natural := Natural(adjusted_bit_num/8)+1;
    bit_offset : Natural := 8-(adjusted_bit_num mod 8)-1;
    orig_byte, new_byte : bitmap_byte_t;
  begin
    if not is_reading then
      sio.set_mode(disk.all, sio.in_file);
    end if;
    sio.set_index(disk.all, sio.count(((start_block-1)*1024)+byte_location)); -- FIXME: +1?
    bitmap_byte_t'read(disk_acc.all, orig_byte);
    new_byte := (orig_byte and not(2#1# * (2**bit_offset))) or (bitmap_byte_t(value) * 2**(bit_offset));
    if not is_writing then
      sio.set_mode(disk.all, sio.out_file);
    end if;
    sio.set_index(disk.all, sio.count(((start_block-1)*1024)+byte_location));
    bitmap_byte_t'write(disk_acc.all, new_byte);
  end set_bit;
  function get_bit (bit_num : bit_nums) return one_bit is
    adjusted_bit_num : Natural := bit_num-1;
    byte_location : Natural := Natural(adjusted_bit_num/8)+1;
    bit_offset : Natural := 8-(adjusted_bit_num mod 8)-1;

    the_byte : bitmap_byte_t;
    shifted_byte : Natural;
  begin
    if not is_reading then
      sio.set_mode(disk.all, sio.in_file);
    end if;
    sio.set_index(disk.all, sio.count(((start_block-1)*1024)+byte_location));
    bitmap_byte_t'read(disk_acc.all, the_byte);
    shifted_byte := Natural(the_byte/(2**bit_offset));
    return one_bit(shifted_byte mod 2) and one_bit(2#1#);
  end get_bit;
end bitmap;

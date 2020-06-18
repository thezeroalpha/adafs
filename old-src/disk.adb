package body disk is
  function init return Boolean is
  begin
    sio.open (disk, sio.OUT_FILE, filename);
    disk_acc := sio.stream(disk);
    if Integer(sio.size (disk)) /= size_bytes then
      tio.put_line ("File size reported as" & size_bytes'Image & ", actual stream size" & sio.size(disk)'Image);
      tio.put_line ("Stopping...");
      return False;
    end if;
    -- do some more checks!
    return True;
  end init;

  procedure close is
  begin
     sio.close(disk);
  end close;

  procedure write_block (num : block_num; e : elem_t) is
  begin
    if not is_writing then
      sio.set_mode(disk, sio.out_file);
    end if;
    go_block (num);
    elem_t'write (disk_acc, e);
  end write_block;

  function read_block (num : block_num) return elem_t is
    result : elem_t;
  begin
    if not is_reading then
      sio.set_mode(disk, sio.in_file);
    end if;
    go_block (num);
    elem_t'read (disk_acc, result);
    return result;
  end read_block;

  procedure zero_block (blk : block_num) is
    type zero_block_arr is array (1..const.block_size) of Character;
    zero_blk : zero_block_arr := (others => Character'Val(0));
    procedure write_zero_block is new write_block (zero_block_arr);
  begin
    if blk /= no_block then
      write_zero_block(blk, zero_blk);
    end if;
  end zero_block;

  procedure zero_disk is
  begin
    tio.put_line ("Zeroing disk");
    for i in 1..size_blocks loop
      zero_block (i);
      tio.put (Character'Val(13) & "complete blocks " & i'Image & "/" & size_blocks'Image);
    end loop;
    tio.put(Character'Val(10));
  end zero_disk;

  procedure go_block (num : block_num) is
    pos : file_position := block2pos(num);
  begin
    sio.set_index (disk, sio.count(pos));
  end go_block;

end disk;

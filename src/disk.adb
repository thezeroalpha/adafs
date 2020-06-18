with Ada.Task_Identification;
package body disk is
  function is_reading return Boolean is (if sio."="(sio.mode(stream_io_disk_ft), sio.in_file) then True else False);
  function is_writing return Boolean is (if sio."="(sio.mode(stream_io_disk_ft), sio.out_file) then True else False);

  procedure go_block (num : block_num) is
    pos : file_position := block2pos(num);
  begin
    sio.set_index (stream_io_disk_ft, sio.count(pos));
  end go_block;

  procedure write_block (num : block_num; e : elem_t) is
  begin
    if not is_writing then
      sio.set_mode(stream_io_disk_ft, sio.out_file);
    end if;
    go_block (num);
    elem_t'write (stream_io_disk_acc, e);
  end write_block;

  function read_block (num : block_num) return elem_t is
    result : elem_t;
  begin
    if not is_reading then
      sio.set_mode(stream_io_disk_ft, sio.in_file);
    end if;
    go_block (num);
    elem_t'read (stream_io_disk_acc, result);
    return result;
  end read_block;

   procedure Initialize (disk : in out disk_t) is
     function read_super is new read_block(adafs.superblock.superblock_t);
   begin
    disk.filename := filename_param;
    sio.open(stream_io_disk_ft, sio.in_file, disk.filename);
    stream_io_disk_acc := sio.stream(stream_io_disk_ft);
    disk.acc := stream_io_disk_ft'Access;

    if Integer(sio.size (disk.acc.all)) /= size_bytes then
      tio.put_line ("File size reported as" & size_bytes'Image & ", actual stream size" & sio.size(disk.acc.all)'Image);
      tio.put_line ("Stopping...");
      Ada.Task_Identification.Abort_Task(Ada.Task_Identification.Current_Task);
    end if;
    disk.super := read_super(adafs.superblock_num);
    if disk.super.magic /= 16#2468# then
      tio.put_line("Magic number mismatch, disk likely not in MINIX format."); -- should do something more meaningful than this
      tio.put_line ("Stopping...");
      Ada.Task_Identification.Abort_Task(Ada.Task_Identification.Current_Task);
    end if;
   end Initialize;


   procedure Finalize (disk : in out disk_t) is
   begin
     sio.close(disk.acc.all);
     disk.filename := (others => adafs.nullchar);
     disk.acc := null;
     disk.super.magic := 0;
   end Finalize;

   disk : aliased disk_t;

   function get_disk return access disk_t is (disk'Access);

   procedure zero_block (blk : block_num) is
     type zero_block_arr is array (1..adafs.block_size) of Character;
     zero_blk : zero_block_arr := (others => adafs.nullchar);
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
       tio.put (adafs.rchar & "complete blocks " & i'Image & "/" & size_blocks'Image);
     end loop;
     tio.put(adafs.nlchar);
   end zero_disk;

end disk;

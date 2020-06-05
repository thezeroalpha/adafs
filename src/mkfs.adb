with Ada.Text_IO;
with Ada.Directories;
with Ada.Streams.Stream_IO;
with const;
procedure mkfs is
  package sio renames Ada.Streams.Stream_IO;
  package tio renames Ada.Text_IO;

  function bshift_l (n, i : Natural) return Natural is (n*(2**i));
  function bshift_r (n, i : Natural) return Natural is (n/(2**i));

  diskname : String := "disk.img";
  disk_size_bytes : Natural := Natural (Ada.Directories.Size(diskname));
  disk_size_bits : Natural := disk_size_bytes*8;
  disk_size_blocks : Natural := disk_size_bytes/const.block_size;
  disk : sio.FILE_TYPE;
  disk_acc : sio.STREAM_ACCESS;

  -- we are using lots of custom sizes to lay out the fs, disable this warning
  pragma Warnings (Off, "*bits of*unused");

  subtype block_num is Natural range 0..disk_size_blocks;
  no_block : constant block_num := 0;

  subtype file_position is Integer range 1..disk_size_bits;
  fpos : file_position;
  subtype disk_position is Integer range 1..disk_size_blocks;
  diskpos : disk_position;

  function block2pos (num : block_num) return file_position is (((num-1)*1024)+1);
  function pos2block (pos : file_position) return block_num is ((pos/const.block_size)+1);

  procedure go_block (num : block_num; pos : out file_position) is
  begin
    pos := block2pos (num);
    sio.set_index (disk, sio.count(pos));
  end go_block;

  function is_reading return Boolean is (if sio."="(sio.mode(disk), sio.in_file) then True else False);
  function is_writing return Boolean is (if sio."="(sio.mode(disk), sio.out_file) then True else False);
  function get_fpos return file_position is (file_position(sio.index(disk)));
  generic
    type elem_t is private;
  procedure write_block (num : block_num; e : elem_t; pos : out file_position);
  procedure write_block (num : block_num; e : elem_t; pos : out file_position) is
  begin
    if not is_writing then
      sio.set_mode(disk, sio.out_file);
    end if;
    go_block (num, pos);
    elem_t'write (disk_acc, e);
  end write_block;

  generic
    type elem_t is private;
  function read_block (num : block_num; pos : out file_position) return elem_t;
  function read_block (num : block_num; pos : out file_position) return elem_t is
    result : elem_t;
  begin
    if not is_reading then
      sio.set_mode(disk, sio.in_file);
    end if;
    go_block (num, pos);
    elem_t'read (disk_acc, result);
    return result;
  end read_block;

  procedure zero_block (blk : block_num) is
    type zero_block_arr is array (1..const.block_size) of Character;
    zero_blk : zero_block_arr := (others => Character'Val(0));
    procedure write_zero_block is new write_block (zero_block_arr);
    pos : file_position;
  begin
    if blk /= no_block then
      write_zero_block(blk, zero_blk, pos);
    end if;
  end zero_block;

  procedure zero_disk is
  begin
    tio.put_line ("Zeroing disk");
    for i in 1..disk_size_blocks loop
      zero_block (i);
      tio.put (Character'Val(13) & "complete blocks " & i'Image & "/" & disk_size_blocks'Image);
    end loop;
    tio.put(Character'Val(10));
  end zero_disk;
  bootblock_num : constant := 1;
  superblock_num : constant := 2;

  procedure write_bootblock is
    type bootblock_t is array (1..const.block_size/4) of String (1..4);
    bootblock : bootblock_t := (bootblock_t'Last-2 => "....", bootblock_t'Last-1 => "ENDS", bootblock_t'Last => "HERE", others=>"BOOT");
    procedure diskwrite_bootblock is new write_block (bootblock_t);
    pos : file_position;
  begin
    diskwrite_bootblock (bootblock_num, bootblock, pos);
    tio.put_line ("Wrote placeholder boot block");
  end write_bootblock;

  type superblock_t is record
    n_inodes : Natural; -- usable inodes
    zones : Natural; -- total device size including bit maps
    imap_blocks : Natural; -- num blocks used by inode bit map
    zmap_blocks : Natural; -- num blocks used by zone bit map
    first_data_zone : Natural; -- number of first data zone
    log_zone_size : Natural; -- log2( blocks/zone )
    max_size : Natural; -- max file size on the device
    magic : Natural; -- superblock magic number
  end record;
  for superblock_t'Size use const.block_size;

  procedure write_superblock (next_datazone, next_inode : out Natural) is
    n_total_zones : constant := 10; -- total zone numbers in inode
    type zone_array is array (1..n_total_zones) of Positive;
    type inode_on_disk is record
      size : Natural; -- file size in bytes
      zone : zone_array;
    end record;
    inode_size : Natural := inode_on_disk'Size;
    inodes_per_block : Natural := const.block_size/inode_size;
    function calc_num_inodes (nblocks : block_num) return Natural is
      inode_max : constant := 65535;
      i : Natural := nblocks/3;
    begin
      i := (if nblocks >= 20000 then nblocks / 4 else i);
      i := (if nblocks >= 40000 then nblocks / 5 else i);
      i := (if nblocks >= 60000 then nblocks / 6 else i);
      i := (if nblocks >= 80000 then nblocks / 7 else i);
      i := (if nblocks >= 100000 then nblocks / 8 else i);
      i := i + inodes_per_block -1;
      i := i / (inodes_per_block*inodes_per_block);
      i := (if i > inode_max then inode_max else i);
      return i;
    end calc_num_inodes;

    inodes : Natural := calc_num_inodes (disk_size_blocks);
    zones : Natural := disk_size_blocks;

    superblock : superblock_t;
    for superblock'Size use const.block_size;
    indirects_size : constant := const.block_size/(Integer'Size/8);
    n_direct_zones : constant := 7;

    function bitmapsize (nbits : Natural) return Natural is
      nblocks : Natural := 0;
      bitmapshift : constant := 13; -- = log2(map_bits_per_block)
    begin
      nblocks := bshift_r (nbits, bitmapshift);
      if (bshift_l(nblocks, bitmapshift) < nbits) then
        nblocks := nblocks+1;
      end if;
      return nblocks;
    end bitmapsize;
    procedure diskwrite_superblock is new write_block (superblock_t);
    pos : file_position;

    imap_blocks : Natural := bitmapsize(1+inodes);
    zmap_blocks : Natural := bitmapsize(zones);

    type imap_block_t is array (1..imap_blocks, 1..const.block_size) of Boolean;
    procedure diskwrite_imap is new write_block (imap_block_t);
    -- inode 1 not used but must be allocated
    inode_map : imap_block_t := (1 => (1 => False, others => True), others => (others => True));

    type zmap_block_t is array (1..zmap_blocks, 1..const.block_size) of Boolean;
    procedure diskwrite_zmap is new write_block (zmap_block_t);
    -- bit zero must always be allocated
    zone_map : zmap_block_t := (1 => (1 => False, others => True), others => (others => True));
    initblks : Natural;
  begin
    superblock.n_inodes := inodes;
    superblock.zones := zones;
    superblock.imap_blocks := imap_blocks;
    superblock.zmap_blocks := zmap_blocks;
    initblks := (superblock.imap_blocks+superblock.zmap_blocks+2) + ((inodes + inodes_per_block -1)/inodes_per_block);
    superblock.first_data_zone := initblks;
    superblock.log_zone_size := 0;
    superblock.magic := 16#2468#;
    superblock.max_size := n_direct_zones + indirects_size + (indirects_size * indirects_size);
    diskwrite_superblock (superblock_num, superblock, pos);

    -- clear maps and inodes
    for i in 3..initblks loop
      zero_block (i);
    end loop;
    -- write maps
    diskwrite_imap (3, inode_map, pos);
    diskwrite_zmap (3+imap_blocks, zone_map, pos);
    tio.put_line(
      "Wrote superblock:"
      & superblock.n_inodes'Image & " inodes," & superblock.zones'Image & " zones"
      & ", max fsize" & superblock.max_size'Image & " bytes"
      & ", first data zone at" & superblock.first_data_zone'Image
      & "," & initblks'Image & " init blks"
      & ", inode map has" & Integer'(inode_map'Length(1)*inode_map'Length(2))'Image & " bits"
      & ", zone map has" & Integer'(zone_map'Length(1)*zone_map'Length(2))'Image & " bits");

    -- Set "return" values
    next_datazone := superblock.first_data_zone;
    next_inode := 2;
  end write_superblock;

  procedure print_pos is
  begin
    tio.put_line ("Current position: bit" & fpos'Image & " block" & diskpos'Image);
  end print_pos;


  next_datazone, next_inode : Natural;
begin
  sio.open(disk, sio.OUT_FILE, diskname);
  disk_acc := sio.stream(disk);
  if Integer(sio.size (disk)) /= disk_size_bytes then
    tio.put_line ("File size reported as" & disk_size_bytes'Image & ", actual stream size" & sio.size(disk)'Image);
    tio.put_line ("Stopping...");
    return;
  end if;
  fpos := get_fpos;
  diskpos := pos2block(fpos);
  tio.Put_Line ("== MKFS-ADAFS ==");
  tio.Put_Line ("disk: " & diskname);
  tio.Put_Line ("size:" & disk_size_bytes'Image & " bytes (" & disk_size_bits'Image & " bits )");
  tio.Put_Line ("blocks:" & disk_size_blocks'Image);
  print_pos;
  write_bootblock;
  write_superblock (next_datazone, next_inode);
  -- write_bitmaps;
  -- write_inodes;
  sio.close(disk);
end mkfs;

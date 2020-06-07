with Ada.Text_IO;
with Ada.Directories;
with Ada.Streams.Stream_IO;
with const;
with bitmap;
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

  next_datazone, next_inode, nrinodes, inode_offset : Natural;

  n_total_zones : constant := 10; -- total zone numbers in inode
  zone_size : Positive := 1; -- zone shift is 0
  zoff : Positive;
  type zone_array is array (1..n_total_zones) of Positive;
  type inode_on_disk is record
    size : Natural; -- file size in bytes
    zone : zone_array;
    nlinks : Natural;
  end record;
  inode_size : Natural := inode_on_disk'Size;
  inodes_per_block : Natural := const.block_size/inode_size;
  imap_blocks : Natural;
  zmap_blocks : Natural;
  n_direct_zones : constant := 7;
  n_indirects_in_block : constant := const.block_size/(Natural'Size/8);

  procedure write_superblock (next_datazone, next_inode : out Natural) is
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

    initblks : Natural;
  begin
    imap_blocks := bitmapsize(1+inodes);
    zmap_blocks := bitmapsize(zones);

    nrinodes := inodes;
    superblock.n_inodes := inodes;
    superblock.zones := zones;
    superblock.imap_blocks := imap_blocks;
    superblock.zmap_blocks := zmap_blocks;
    inode_offset := superblock.imap_blocks + superblock.zmap_blocks+2;
    initblks := (superblock.imap_blocks+superblock.zmap_blocks+2) + ((inodes + inodes_per_block -1)/inodes_per_block);
    superblock.first_data_zone := initblks;
    zoff := superblock.first_data_zone-1;
    superblock.log_zone_size := 0;
    superblock.magic := 16#2468#;
    superblock.max_size := n_direct_zones + n_indirects_in_block + (n_indirects_in_block * n_indirects_in_block);
    diskwrite_superblock (superblock_num, superblock, pos);

    -- clear maps and inodes
    for i in 3..initblks loop
      zero_block (i);
    end loop;
    -- write maps
    declare
      package inode_bitmap is new bitmap (bitmap_blocks => imap_blocks, start_block => 3, block_size_bytes => 1024, disk => disk'Access, disk_acc => disk_acc'Access);
      package zone_bitmap is new bitmap (bitmap_blocks => zmap_blocks, start_block => 4, block_size_bytes => 1024, disk => disk'Access, disk_acc => disk_acc'Access);
    begin
      inode_bitmap.init;
      zone_bitmap.init;
      tio.put_line(
        "Wrote superblock:"
        & superblock.n_inodes'Image & " inodes," & superblock.zones'Image & " zones"
        & ", max fsize" & superblock.max_size'Image & " bytes"
        & ", first data zone at" & superblock.first_data_zone'Image
        & "," & initblks'Image & " init blks"
        & ", zone map has" & zone_bitmap.size_bits'Image & " bits"
        & ", inode map has" & inode_bitmap.size_bits'Image & " bits");
    end;

    -- Set "return" values
    next_datazone := superblock.first_data_zone;
    next_inode := 2;
  end write_superblock;

  procedure create_rootdir is
    function alloc_inode return Positive is
      num : Positive := next_inode+1;
      block_num : Positive := (num/inodes_per_block) + inode_offset;
      offset : Natural := num mod inodes_per_block;
      type inode_block_t is array (1..inodes_per_block) of inode_on_disk;
      function read_inode_block is new read_block (inode_block_t);
      procedure write_inode_block is new write_block (inode_block_t);
      inode_block : inode_block_t;
      pos : file_position;
      package inode_bitmap is new bitmap (bitmap_blocks => imap_blocks, start_block => 3, block_size_bytes => 1024, disk => disk'Access, disk_acc => disk_acc'Access);
    begin
      inode_block := read_inode_block (block_num, pos);
      inode_block(offset).nlinks := 0;
      write_inode_block (block_num, inode_block, pos);
      inode_bitmap.set_bit(num-1, 1);
      next_inode := next_inode+1;
      return num;
    end alloc_inode;

    function alloc_zone return Positive is
      z : Positive := next_datazone+1;
      b : Positive := z;
    begin
      for i in 1..zone_size loop
        zero_block(b+i);
      end loop;
      declare
        package zone_bitmap is new bitmap (bitmap_blocks => zmap_blocks, start_block => 4, block_size_bytes => 1024, disk => disk'Access, disk_acc => disk_acc'Access);
      begin
        zone_bitmap.set_bit(z-zoff, 1);
      end;
      next_datazone := next_datazone+1;
      return z;
    end alloc_zone;

    root_inum : Positive := alloc_inode;
    zone_num : Positive := alloc_zone;

    -- add zone z to inode n, the file has grown by 'grow_by_bytes' bytes
    procedure add_zone (inode_num : Positive; zone_num : Positive; grow_by_bytes : Positive) is
      block_num : Positive := (inode_num-1)/inodes_per_block + inode_offset + 1;
      offset : Natural := (inode_num-1) mod inodes_per_block;
      type inode_block_t is array (1..inodes_per_block) of inode_on_disk;
      inode_block : inode_block_t;
      function read_inode_block is new read_block (inode_block_t);
      procedure write_inode_block is new write_block (inode_block_t);
      type zone_block_t is array (1..n_indirects_in_block) of Natural;
      zone_block : zone_block_t;
      function read_zone_block is new read_block (zone_block_t);
      procedure write_zone_block is new write_block (zone_block_t);
      ino : inode_on_disk;
      pos : file_position;
      indir : Natural;
    begin
      inode_block := read_inode_block(block_num, pos);
      ino := inode_block(offset+1);
      ino.size := ino.size + grow_by_bytes;
      for i in 1..n_direct_zones loop
        if ino.zone(i) = 0 then
          ino.zone(i) := zone_num;
          inode_block(offset+1) := ino;
          write_inode_block(block_num, inode_block, pos);
          return;
        end if;
      end loop;
      write_inode_block(block_num, inode_block, pos);

      if ino.zone(n_direct_zones) = 0 then
        ino.zone(n_direct_zones) := alloc_zone;
      end if;
      indir := ino.zone(n_direct_zones);
      inode_block(offset) := ino;
      write_inode_block(block_num, inode_block, pos);
      block_num := indir; -- zone_shift is 0
      zone_block := read_zone_block (block_num, pos);
      for i in 1..n_indirects_in_block loop
        if zone_block(i) = 0 then
          zone_block(i) := zone_num;
          write_zone_block(block_num, zone_block, pos);
          return;
        end if;
      end loop;
    end add_zone;

    -- enter child in parent directory
    procedure enter_dir (parent_inum : Positive; name : String; child_inum : Positive) is
      block_num : Natural := ((parent_inum-1)/inodes_per_block)+inode_offset+1;
      offset : Natural := (parent_inum-1) mod inodes_per_block;
      pos : file_position;

      type inode_block_t is array (1..inodes_per_block) of inode_on_disk;
      function read_inode_block is new read_block (inode_block_t);
      procedure write_inode_block is new write_block (inode_block_t);
      inode_block : inode_block_t;


      type direct is record
        inode_num : Natural;
        name: String(1..14); -- 14 == DIRSIZ
      end record;
      nr_dir_entries : Natural := const.block_size/direct'Size;
      type dir_entry_block is array (1..nr_dir_entries) of direct;
      function read_dir_entry_block is new read_block (dir_entry_block);
      procedure write_dir_entry_block is new write_block (dir_entry_block);
      dir_block : dir_entry_block;
    begin
      inode_block := read_inode_block (block_num, pos);

      for i in 1..n_direct_zones loop
        zone_num := inode_block(offset+1).zone(i);
        if zone_num = 0 then
          zone_num := alloc_zone;
          inode_block(offset+1).zone(i) := zone_num;
        end if;

        for j in 1..zone_size loop
          dir_block := read_dir_entry_block(zone_num+j, pos);
          for k in 1..nr_dir_entries loop
            if dir_block(k).inode_num = 0 then
              dir_block(k).inode_num := child_inum;
              dir_block(k).name := name & (1..14-name'Length => Character'Val(0));
              write_dir_entry_block (zone_num+j, dir_block, pos);
              write_inode_block (block_num, inode_block, pos);
              return;
            end if;
          end loop;
        end loop;
      end loop;
    end enter_dir;

    procedure incr_link (inum : Positive) is
      block_num : Positive := ((inum-1)/inodes_per_block)+inode_offset+1;
      offset : Natural := (inum-1) mod inodes_per_block;
      type inode_block_t is array (1..inodes_per_block) of inode_on_disk;
      inode_block : inode_block_t;
      procedure write_inode_block is new write_block (inode_block_t);
      function read_inode_block is new read_block (inode_block_t);
      pos : file_position;
    begin
      inode_block := read_inode_block(block_num, pos);
      inode_block(offset+1).nlinks := inode_block(offset+1).nlinks+1;
      write_inode_block(block_num, inode_block, pos);
    end incr_link;

  begin
    add_zone(root_inum, zone_num, 32);
    enter_dir(root_inum, ".", root_inum);
    enter_dir(root_inum, "..", root_inum);
    incr_link(root_inum);
    incr_link(root_inum);
  end create_rootdir;

  procedure print_pos is
  begin
    tio.put_line ("Current position: bit" & fpos'Image & " block" & diskpos'Image);
  end print_pos;

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
  create_rootdir;
  sio.close(disk);
end mkfs;

with Ada.Text_IO;
with Ada.Streams.Stream_IO;
with const;
with bitmap;
with disk;
with boot;
with util;
with inode;
with superblock;
procedure mkfs is
  package sio renames Ada.Streams.Stream_IO;
  package tio renames Ada.Text_IO;
  package dsk is new disk ("disk.img");

  -- we are using lots of custom sizes to lay out the fs, disable this warning
  pragma Warnings (Off, "*bits of*unused");

  function bitmapsize_in_blocks (nbits : Natural) return Natural is
    nblocks : Natural := 0;
    bitmapshift : constant := 13; -- = log2(map_bits_per_block)
  begin
    nblocks := util.bshift_r (nbits, bitmapshift);
    if (util.bshift_l(nblocks, bitmapshift) < nbits) then
      nblocks := nblocks+1;
    end if;
    return nblocks;
  end bitmapsize_in_blocks;

  package inode_bitmap is new bitmap (
    bitmap_blocks => bitmapsize_in_blocks(1+dsk.n_inodes),
    start_block => 3,
    block_size_bytes => const.block_size,
    disk => dsk.disk'Access,
    disk_acc => dsk.disk_acc'Access);

  package zone_bitmap is new bitmap (
    bitmap_blocks => bitmapsize_in_blocks(dsk.n_zones),
    start_block => inode_bitmap.get_start_block+inode_bitmap.size_in_blocks,
    block_size_bytes => const.block_size,
    disk => dsk.disk'Access,
    disk_acc => dsk.disk_acc'Access);

  procedure write_bootblock is
    procedure write_boot is new dsk.write_block (boot.bootblock_t);
    bootblock : boot.bootblock_t := (
      boot.bootblock_t'Last-2 => "....",
      boot.bootblock_t'Last-1 => "ENDS",
      boot.bootblock_t'Last => "HERE",
      others=>"BOOT");
  begin
    write_boot (dsk.bootblock_num, bootblock);
    tio.put_line ("Wrote placeholder boot block");
  end write_bootblock;

  procedure write_superblock (next_datazone, next_inode, zoff, inode_offset : out Natural) is
    super : superblock.superblock_t;
    for super'Size use const.block_size;
    procedure diskwrite_superblock is new dsk.write_block (superblock.superblock_t);
    n_initblks : Natural;
  begin
    -- Set "global" values
    inode_offset := inode_bitmap.size_in_blocks + zone_bitmap.size_in_blocks + 2;
    n_initblks := (inode_offset) + ((dsk.n_inodes + inode.num_per_block - 1)/inode.num_per_block);
    zoff := n_initblks-1;
    next_datazone := n_initblks;
    next_inode := 2;

    super := (
      n_inodes => dsk.n_inodes,
      zones => dsk.n_zones,
      imap_blocks => inode_bitmap.size_in_blocks,
      zmap_blocks => zone_bitmap.size_in_blocks,
      first_data_zone => n_initblks,
      log_zone_size => 0,
      magic => 16#2468#,
      max_size => inode.max_file_size);

    diskwrite_superblock (dsk.superblock_num, super);

    -- clear maps and inodes
    for i in 3..n_initblks loop
      dsk.zero_block (i);
    end loop;
    -- write maps
    inode_bitmap.init;
    zone_bitmap.init;
    tio.put_line(
      "Wrote superblock:"
      & super.n_inodes'Image & " inodes," & super.zones'Image & " zones"
      & ", max fsize" & super.max_size'Image & " bytes"
      & ", first data zone at" & super.first_data_zone'Image
      & "," & n_initblks'Image & " init blks"
      & ", zone map has" & zone_bitmap.size_in_bits'Image & " bits"
      & ", inode map has" & inode_bitmap.size_in_bits'Image & " bits");

  end write_superblock;

  procedure create_rootdir (next_datazone, next_inode : in out Natural; zoff, inode_offset : in Natural) is
    function read_inode_block is new dsk.read_block (inode.inode_block_t);
    procedure write_inode_block is new dsk.write_block (inode.inode_block_t);

    function alloc_inode return Positive is
      num : Positive := next_inode+1;
      block_num : Positive := (num/inode.num_per_block) + inode_offset;
      offset : Natural := num mod inode.num_per_block;
      inode_block : inode.inode_block_t;
    begin
      inode_block := read_inode_block (block_num);
      inode_block(offset).nlinks := 0;
      write_inode_block (block_num, inode_block);
      inode_bitmap.set_bit(num-1, 1);
      next_inode := next_inode+1;
      return num;
    end alloc_inode;

    function alloc_zone return Positive is
      z : Positive := next_datazone+1;
      b : Positive := z;
    begin
      for i in 1..inode.zone_size loop
        dsk.zero_block(b+i);
      end loop;
      zone_bitmap.set_bit(z-zoff, 1);
      next_datazone := next_datazone+1;
      return z;
    end alloc_zone;

    root_inum : Positive := alloc_inode;
    zone_num : Positive := alloc_zone;

    -- add zone z to inode n, the file has grown by 'grow_by_bytes' bytes
    procedure add_zone (inode_num : Positive; zone_num : Positive; grow_by_bytes : Positive) is
      block_num : Positive := (inode_num-1)/inode.num_per_block + inode_offset + 1;
      offset : Natural := (inode_num-1) mod inode.num_per_block;
      inode_block : inode.inode_block_t;
      zone_block : inode.zone_block_t;
      function read_zone_block is new dsk.read_block (inode.zone_block_t);
      procedure write_zone_block is new dsk.write_block (inode.zone_block_t);
      ino : inode.on_disk;
      indir : Natural;
    begin
      inode_block := read_inode_block(block_num);
      ino := inode_block(offset+1);
      ino.size := ino.size + grow_by_bytes;
      for i in 1..inode.n_direct_zones loop
        if ino.zone(i) = 0 then
          ino.zone(i) := zone_num;
          inode_block(offset+1) := ino;
          write_inode_block(block_num, inode_block);
          return;
        end if;
      end loop;
      write_inode_block(block_num, inode_block);

      if ino.zone(inode.n_direct_zones) = 0 then
        ino.zone(inode.n_direct_zones) := alloc_zone;
      end if;
      indir := ino.zone(inode.n_direct_zones);
      inode_block(offset) := ino;
      write_inode_block(block_num, inode_block);
      block_num := indir; -- zone_shift is 0
      zone_block := read_zone_block (block_num);
      for i in 1..inode.n_indirects_in_block loop
        if zone_block(i) = 0 then
          zone_block(i) := zone_num;
          write_zone_block(block_num, zone_block);
          return;
        end if;
      end loop;
    end add_zone;

    -- enter child in parent directory
    procedure enter_dir (parent_inum : Positive; name : String; child_inum : Positive) is
      block_num : Natural := ((parent_inum-1)/inode.num_per_block)+inode_offset+1;
      offset : Natural := (parent_inum-1) mod inode.num_per_block;
      inode_block : inode.inode_block_t;

      function read_dir_entry_block is new dsk.read_block (inode.dir_entry_block);
      procedure write_dir_entry_block is new dsk.write_block (inode.dir_entry_block);
      dir_block : inode.dir_entry_block;
    begin
      inode_block := read_inode_block (block_num);

      for i in 1..inode.n_direct_zones loop
        zone_num := inode_block(offset+1).zone(i);
        if zone_num = 0 then
          zone_num := alloc_zone;
          inode_block(offset+1).zone(i) := zone_num;
        end if;

        for j in 1..inode.zone_size loop
          dir_block := read_dir_entry_block(zone_num+j);
          for k in 1..inode.nr_dir_entries loop
            if dir_block(k).inode_num = 0 then
              dir_block(k).inode_num := child_inum;
              dir_block(k).name := name & (1..14-name'Length => Character'Val(0));
              write_dir_entry_block (zone_num+j, dir_block);
              write_inode_block (block_num, inode_block);
              return;
            end if;
          end loop;
        end loop;
      end loop;
    end enter_dir;

    procedure incr_link (inum : Positive) is
      block_num : Positive := ((inum-1)/inode.num_per_block)+inode_offset+1;
      offset : Natural := (inum-1) mod inode.num_per_block;
      inode_block : inode.inode_block_t;
    begin
      inode_block := read_inode_block(block_num);
      inode_block(offset+1).nlinks := inode_block(offset+1).nlinks+1;
      write_inode_block(block_num, inode_block);
    end incr_link;

  begin
    add_zone(root_inum, zone_num, 32);
    enter_dir(root_inum, ".", root_inum);
    enter_dir(root_inum, "..", root_inum);
    incr_link(root_inum);
    incr_link(root_inum);
    tio.put_line ("Root directory written");
  end create_rootdir;

  zoff, next_datazone, next_inode, inode_offset : Natural;
begin
  if not dsk.init then
    tio.put_line ("Disk failed to initialize");
    return;
  end if;
  tio.Put_Line ("== MKFS-ADAFS ==");
  tio.Put_Line ("disk: " & dsk.name);
  tio.Put_Line ("size:" & dsk.size_bytes'Image & " bytes (" & dsk.size_in_bits'Image & " bits )");
  tio.Put_Line ("blocks:" & dsk.size_blocks'Image);
  write_bootblock;
  write_superblock (next_datazone, next_inode, zoff, inode_offset);
  create_rootdir (next_datazone, next_inode, zoff, inode_offset);
  dsk.close;
  tio.put_line ("adafs created on " & dsk.name);
end mkfs;

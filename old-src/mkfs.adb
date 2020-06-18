with Ada.Text_IO, Ada.Streams.Stream_IO;
with const, bitmap, disk, boot, util, superblock;
with disk.inode;
with inode_types;
procedure mkfs is
  package sio renames Ada.Streams.Stream_IO;
  package tio renames Ada.Text_IO;
  package dsk is new disk ("disk.img");
  super : superblock.superblock_t;
  for super'Size use const.block_size;

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
    procedure diskwrite_superblock is new dsk.write_block (superblock.superblock_t);
    n_initblks : Natural;
  begin
    -- Set "global" values
    inode_offset := inode_bitmap.size_in_blocks + zone_bitmap.size_in_blocks + 3;
    n_initblks := (inode_offset) + (((dsk.n_inodes + inode_types.num_per_block - 1)/inode_types.num_per_block));
    zoff := n_initblks-1;
    next_datazone := n_initblks;
    next_inode := 1;

    super.n_inodes := dsk.n_inodes;
    super.zones := dsk.n_zones;
    super.imap_blocks := inode_bitmap.size_in_blocks;
    super.zmap_blocks := zone_bitmap.size_in_blocks;
    super.first_data_zone := n_initblks;
    super.log_zone_size := 0;
    super.magic := 16#2468#;
    declare
      package inode is new dsk.inode (super);
    begin
      super.max_size := inode.max_file_size;
    end;

    diskwrite_superblock (dsk.superblock_num, super);

    -- clear maps and inodes
    for i in 3..n_initblks loop
      dsk.zero_block (i);
    end loop;
    -- write maps
    inode_bitmap.init;
    zone_bitmap.init;
    declare
      nl : Character := Character'Val(10);
    begin
      tio.put_line(
        "Wrote superblock:" &nl
        & "- zones:" & super.zones'Image &nl
        & "- bits in zmap:" & zone_bitmap.size_in_bits'Image & " -" & Natural'(zone_bitmap.size_in_blocks)'Image & " blocks" &nl
        & "- bits in imap:" & inode_bitmap.size_in_bits'Image & " -" & Natural'(inode_bitmap.size_in_blocks)'Image & " blocks" &nl
        & "- inodes:" & super.n_inodes'Image &nl
        & "- inodes per block:" & inode_types.num_per_block'Image &nl
        & "- inodes start at block:" & inode_offset'Image &nl
        & "- inode blocks:" & Natural'(((dsk.n_inodes + inode_types.num_per_block-1)/inode_types.num_per_block))'Image &nl
        & "- first data zone:" & super.first_data_zone'Image &nl
        & "- num init blocks:" & n_initblks'Image &nl
        & "- max fsize:" & super.max_size'Image & " bytes" &nl
        );
    end;

  end write_superblock;

  procedure create_rootdir (next_datazone, next_inode : in out Natural; zoff, inode_offset : in Natural) is
    package inode is new dsk.inode (super);
    function read_inode_block is new dsk.read_block (inode.inode_block_t);
    procedure write_inode_block is new dsk.write_block (inode.inode_block_t);

    function alloc_inode return Positive is
      num : Positive := next_inode;
      block_num : Positive := inode_offset + (((num-1)/inode_types.num_per_block)+1);
      offset : Natural := ((num-1) mod inode_types.num_per_block) + 1;
      inode_block : inode.inode_block_t;
    begin
      inode_block := read_inode_block (block_num);
      inode_block(offset).nlinks := 0;
      write_inode_block (block_num, inode_block);
      inode_bitmap.set_bit(num, 1);
      next_inode := next_inode+1;
      return num;
    end alloc_inode;

    function alloc_zone return Positive is
      z : Positive := next_datazone;
      b : Positive := z;
    begin
      for i in 1..inode.zone_size loop
        dsk.zero_block(b+i-1);
      end loop;
      zone_bitmap.set_bit(z-zoff, 1);
      next_datazone := next_datazone+1;
      return z;
    end alloc_zone;

    root_inum : Positive := alloc_inode;
    zone_num : Positive := alloc_zone;

    -- add zone z to inode n, the file has grown by 'grow_by_bytes' bytes
    procedure add_zone (inode_num : Positive; zone_num : Positive; grow_by_bytes : Positive) is
      block_num : Positive := (inode_num-1)/inode_types.num_per_block + inode_offset;
      offset : Natural := ((inode_num-1) mod inode_types.num_per_block)+1;
      inode_block : inode.inode_block_t;
      zone_block : inode.zone_block_t;
      function read_zone_block is new dsk.read_block (inode.zone_block_t);
      procedure write_zone_block is new dsk.write_block (inode.zone_block_t);
      ino : inode_types.on_disk;
      indir : Natural;
    begin
      inode_block := read_inode_block(block_num);
      ino := inode_block(offset);
      ino.size := ino.size + grow_by_bytes;
      for i in 1..inode.n_direct_zones loop
        if ino.zone(i) = 0 then
          ino.zone(i) := zone_num;
          inode_block(offset) := ino;
          write_inode_block(block_num, inode_block);
          tio.put_line ("added #" & i'Image & " direct zone num" & zone_num'Image &" to inode" & inode_num'Image);
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
      block_num : Natural := ((parent_inum-1)/inode_types.num_per_block)+inode_offset;
      offset : Natural := ((parent_inum-1) mod inode_types.num_per_block)+1;
      inode_block : inode.inode_block_t;

      function read_dir_entry_block is new dsk.read_block (inode.dir_entry_block_t);
      procedure write_dir_entry_block is new dsk.write_block (inode.dir_entry_block_t);
      dir_block : inode.dir_entry_block_t;
    begin
      inode_block := read_inode_block (block_num);

      for i in 1..inode.n_direct_zones loop
        zone_num := inode_block(offset).zone(i);
        if zone_num = 0 then
          zone_num := alloc_zone;
          inode_block(offset).zone(i) := zone_num;
        end if;

        for j in 1..inode.zone_size loop
          dir_block := read_dir_entry_block(zone_num+j-1);
          for k in 1..inode.nr_dir_entries loop
            if dir_block(k).inode_num = 0 then
              dir_block(k).inode_num := child_inum;
              dir_block(k).name := name & (1..14-name'Length => Character'Val(0));
              write_dir_entry_block (zone_num+j-1, dir_block);
              write_inode_block (block_num, inode_block);
              tio.put_line("wrote dir '" & name & "' to block" & Natural'(zone_num+j-1)'Image & " (zone" & zone_num'Image & ")");
              return;
            end if;
          end loop;
        end loop;
      end loop;
    end enter_dir;

    procedure incr_link (inum : Positive) is
      block_num : Positive := ((inum-1)/inode_types.num_per_block)+inode_offset;
      offset : Natural := (inum-1) mod inode_types.num_per_block;
      inode_block : inode.inode_block_t;
    begin
      inode_block := read_inode_block(block_num);
      inode_block(offset+1).nlinks := inode_block(offset+1).nlinks+1;
      write_inode_block(block_num, inode_block);
    end incr_link;

  begin
    add_zone(root_inum, zone_num, 2*inode.direct'Size);
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
  dsk.zero_disk;
  tio.Put_Line ("zeroed successfully");
  tio.Put_Line ("size:" & dsk.size_bytes'Image & " B," & Natural'(dsk.size_bytes/1E3)'Image & " KB," & Natural'(dsk.size_bytes/1E6)'Image & " GB," & dsk.size_in_bits'Image & " bits");
  tio.Put_Line ("blocks:" & dsk.size_blocks'Image);
  write_bootblock;
  write_superblock (next_datazone, next_inode, zoff, inode_offset);
  create_rootdir (next_datazone, next_inode, zoff, inode_offset);
  dsk.close;
  tio.put_line ("adafs created on " & dsk.name);
end mkfs;
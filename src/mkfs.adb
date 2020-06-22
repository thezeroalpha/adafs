with Ada.Text_IO, Ada.Streams.Stream_IO;
with disk;
with disk.bitmap;
with disk.inode;
with adafs.superblock;
with adafs.boot;
with adafs.inode;
procedure mkfs is
  package sio renames Ada.Streams.Stream_IO;
  package tio renames Ada.Text_IO;
  super : adafs.superblock.superblock_t;
  for super'Size use adafs.block_size;

  -- we are using lots of custom sizes to lay out the fs, disable this warning
  pragma Warnings (Off, "*bits of*unused");

  function bitmapsize_in_blocks (nbits : Natural) return Natural is
    nblocks : Natural := 0;
    bitmapshift : constant := 13; -- = log2(map_bits_per_block)
  begin
    nblocks := adafs.bshift_r (nbits, bitmapshift);
    if (adafs.bshift_l(nblocks, bitmapshift) < nbits) then
      nblocks := nblocks+1;
    end if;
    return nblocks;
  end bitmapsize_in_blocks;

  package inode_bitmap is new disk.bitmap (
    n_bitmap_blocks => bitmapsize_in_blocks(1+disk.n_inodes),
    start_block => adafs.imap_start);

  package zone_bitmap is new disk.bitmap (
    n_bitmap_blocks => bitmapsize_in_blocks(disk.n_zones),
    start_block => adafs.imap_start+bitmapsize_in_blocks(1+disk.n_inodes));

  procedure write_bootblock is
    procedure write_boot is new disk.write_block (adafs.boot.bootblock_t);
    bootblock : adafs.boot.bootblock_t := (
      adafs.boot.bootblock_t'Last-2 => "....",
      adafs.boot.bootblock_t'Last-1 => "ENDS",
      adafs.boot.bootblock_t'Last => "HERE",
      others=>"BOOT");
  begin
    write_boot (adafs.bootblock_num, bootblock);
    tio.put_line ("Wrote placeholder boot block");
  end write_bootblock;

  procedure write_superblock (next_datazone, next_inode, zoff, inode_offset : out Natural) is
    procedure diskwrite_superblock is new disk.write_block (adafs.superblock.superblock_t);
    n_initblks : Natural;
  begin
    -- Set "global" values
    inode_offset := inode_bitmap.size_in_blocks + zone_bitmap.size_in_blocks + 3;
    n_initblks := (inode_offset) + (((disk.n_inodes + adafs.inode.num_per_block - 1)/adafs.inode.num_per_block));
    zoff := n_initblks-1;
    next_datazone := n_initblks;
    next_inode := 1;

    super.n_inodes := disk.n_inodes;
    super.zones := disk.n_zones;
    super.imap_blocks := inode_bitmap.size_in_blocks;
    super.zmap_blocks := zone_bitmap.size_in_blocks;
    super.first_data_zone := n_initblks;
    super.log_zone_size := 0;
    super.magic := 16#2468#;
    super.max_size := adafs.inode.max_file_size;

    diskwrite_superblock (adafs.superblock_num, super);

    -- clear maps and inodes
    for i in 3..n_initblks loop
      disk.zero_block (i);
    end loop;
    declare
      nl : Character := Character'Val(10);
    begin
      tio.put_line(
        "Wrote superblock:" &nl
        & "- zones:" & super.zones'Image &nl
        & "- bits in zmap:" & zone_bitmap.size_in_bits'Image & " -" & Natural'(zone_bitmap.size_in_blocks)'Image & " blocks" &nl
        & "- bits in imap:" & inode_bitmap.size_in_bits'Image & " -" & Natural'(inode_bitmap.size_in_blocks)'Image & " blocks" &nl
        & "- inodes:" & super.n_inodes'Image &nl
        & "- inodes per block:" & adafs.inode.num_per_block'Image &nl
        & "- inodes start at block:" & inode_offset'Image &nl
        & "- inode blocks:" & Natural'(((disk.n_inodes + adafs.inode.num_per_block-1)/adafs.inode.num_per_block))'Image &nl
        & "- first data zone:" & super.first_data_zone'Image &nl
        & "- num init blocks:" & n_initblks'Image &nl
        & "- max fsize:" & super.max_size'Image & " bytes" &nl
        );
    end;

  end write_superblock;

  procedure create_rootdir (next_datazone, next_inode : in out Natural; zoff, inode_offset : in Natural) is
    function read_inode_block is new disk.read_block (adafs.inode.inode_block_t);
    procedure write_inode_block is new disk.write_block (adafs.inode.inode_block_t);

    function alloc_inode return Positive is
      num : Positive := next_inode;
      block_num : Positive := inode_offset + (((num-1)/adafs.inode.num_per_block)+1);
      offset : Natural := ((num-1) mod adafs.inode.num_per_block) + 1;
      inode_block : adafs.inode.inode_block_t;
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
      for i in 1..adafs.inode.zone_size loop
        disk.zero_block(b+i-1);
      end loop;
      zone_bitmap.set_bit(z-zoff, 1);
      next_datazone := next_datazone+1;
      return z;
    end alloc_zone;

    root_inum : Positive;
    zone_num : Positive;

    -- add zone z to inode n, the file has grown by 'grow_by_bytes' bytes
    procedure add_zone (inode_num : Positive; zone_num : Positive; grow_by_bytes : Positive) is
      block_num : Positive := (inode_num-1)/adafs.inode.num_per_block + inode_offset;
      offset : Natural := ((inode_num-1) mod adafs.inode.num_per_block)+1;
      inode_block : adafs.inode.inode_block_t;
      zone_block : adafs.inode.zone_block_t;
      function read_zone_block is new disk.read_block (adafs.inode.zone_block_t);
      procedure write_zone_block is new disk.write_block (adafs.inode.zone_block_t);
      ino : adafs.inode.on_disk;
      indir : Natural;
    begin
      inode_block := read_inode_block(block_num);
      ino := inode_block(offset);
      ino.size := ino.size + grow_by_bytes;
      for i in 1..adafs.inode.n_direct_zones loop
        if ino.zone(i) = 0 then
          ino.zone(i) := zone_num;
          inode_block(offset) := ino;
          write_inode_block(block_num, inode_block);
          tio.put_line ("added #" & i'Image & " direct zone num" & zone_num'Image &" to inode" & inode_num'Image);
          return;
        end if;
      end loop;
      write_inode_block(block_num, inode_block);

      if ino.zone(adafs.inode.n_direct_zones) = 0 then
        ino.zone(adafs.inode.n_direct_zones) := alloc_zone;
      end if;
      indir := ino.zone(adafs.inode.n_direct_zones);
      inode_block(offset) := ino;
      write_inode_block(block_num, inode_block);
      block_num := indir; -- zone_shift is 0
      zone_block := read_zone_block (block_num);
      for i in 1..adafs.inode.n_indirects_in_block loop
        if zone_block(i) = 0 then
          zone_block(i) := zone_num;
          write_zone_block(block_num, zone_block);
          return;
        end if;
      end loop;
    end add_zone;

    -- enter child in parent directory
    procedure enter_dir (parent_inum : Positive; name : String; child_inum : Positive) is
      block_num : Natural := ((parent_inum-1)/adafs.inode.num_per_block)+inode_offset;
      offset : Natural := ((parent_inum-1) mod adafs.inode.num_per_block)+1;
      inode_block : adafs.inode.inode_block_t;

      function read_dir_entry_block is new disk.read_block (adafs.inode.dir_entry_block_t);
      procedure write_dir_entry_block is new disk.write_block (adafs.inode.dir_entry_block_t);
      dir_block : adafs.inode.dir_entry_block_t;

      nr_dir_entries : Natural := adafs.block_size/adafs.inode.direct'Size;
    begin
      inode_block := read_inode_block (block_num);

      for i in 1..adafs.inode.n_direct_zones loop
        zone_num := inode_block(offset).zone(i);
        if zone_num = 0 then
          zone_num := alloc_zone;
          inode_block(offset).zone(i) := zone_num;
        end if;

        for j in 1..adafs.inode.zone_size loop
          dir_block := read_dir_entry_block(zone_num+j-1);
          for k in 1..nr_dir_entries loop
            if dir_block(k).inode_num = 0 then
              dir_block(k).inode_num := child_inum;
              dir_block(k).name := name & (1..adafs.name_t'Last-name'Length => Character'Val(0));
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
      block_num : Positive := ((inum-1)/adafs.inode.num_per_block)+inode_offset;
      offset : Natural := (inum-1) mod adafs.inode.num_per_block;
      inode_block : adafs.inode.inode_block_t;
    begin
      inode_block := read_inode_block(block_num);
      inode_block(offset+1).nlinks := inode_block(offset+1).nlinks+1;
      write_inode_block(block_num, inode_block);
    end incr_link;

  begin
    inode_bitmap.clear_bitmap;
    zone_bitmap.clear_bitmap;
    root_inum := alloc_inode;
    zone_num := alloc_zone;
    add_zone(root_inum, zone_num, 2*adafs.inode.direct'Size);
    enter_dir(root_inum, ".", root_inum);
    enter_dir(root_inum, "..", root_inum);
    incr_link(root_inum);
    incr_link(root_inum);
    tio.put_line ("Root directory written");
  end create_rootdir;

  zoff, next_datazone, next_inode, inode_offset : Natural;
begin
  tio.Put_Line ("== MKFS-ADAFS ==");
  tio.Put_Line ("disk: " & disk.get_disk.filename);
  disk.zero_disk;
  tio.Put_Line ("zeroed successfully");
  tio.Put_Line ("size:" & disk.size_bytes'Image & " B," & Natural'(disk.size_bytes/1E3)'Image & " KB," & Natural'(disk.size_bytes/1E6)'Image & " GB," & disk.size_in_bits'Image & " bits");
  tio.Put_Line ("blocks:" & disk.size_blocks'Image);
  write_bootblock;
  write_superblock (next_datazone, next_inode, zoff, inode_offset);
  create_rootdir (next_datazone, next_inode, zoff, inode_offset);
  tio.put_line ("adafs created on " & disk.get_disk.filename);
end mkfs;

package body disk.inode is
  procedure set_super (sp : superblock.superblock_t) is
  begin
    super := sp;
  end set_super;

  function get_inode (num : Natural) return in_mem is
    offset : Natural := 3+super.imap_blocks+super.zmap_blocks;
    bnum : block_num := ((num-1)/num_per_block)+offset;
    function disk_read_iblock is new read_block(inode_block_t);
    iblock : inode_block_t := disk_read_iblock(bnum);
    pos_in_block : Natural range 1..num_per_block := ((num-1) mod num_per_block)+1;
    ino_read : on_disk := iblock(pos_in_block);

    ino : in_mem := (
      size => ino_read.size,
      zone => ino_read.zone,
      nlinks => ino_read.nlinks,
      num => num,
      count => 0,
      n_dzones => n_direct_zones,
      n_indirs => n_indirects_in_block);
  begin
    return ino;
  end get_inode;

  procedure put_inode (ino : in_mem) is
    offset : Natural := 3+super.imap_blocks+super.zmap_blocks;
    bnum : block_num := ((ino.num-1)/num_per_block)+offset;
    function disk_read_iblock is new read_block(inode_block_t);
    procedure disk_write_iblock is new write_block(inode_block_t);
    iblock : inode_block_t := disk_read_iblock(bnum);
    pos_in_block : Natural range 1..num_per_block := ((ino.num-1) mod num_per_block)+1;

    ino_to_write : on_disk := (
      size => ino.size,
      zone => ino.zone,
      nlinks => ino.nlinks);
  begin
    iblock(pos_in_block) := ino_to_write;
    disk_write_iblock(bnum, iblock);
  end put_inode;

  function inode_fpos_to_bnum (ino : in_mem; fpos : Natural) return Natural is
    --analogous to minix read.c:read_map
    scale : Natural := super.log_zone_size; -- for block-zone conversion
    block_pos : Natural := ((fpos-1)/const.block_size)+1; -- relative block num in file (e.g. "block 2 of file")
    zone_num : Natural := util.bshift_r (block_pos, scale); -- position's zone
    block_pos_in_zone : Natural := block_pos-(util.bshift_l(zone_num, scale));
    dzones : Natural := ino.n_dzones;

    index, excess, znum, bnum : Natural;
  begin
    -- if the zone is direct (in the inode itself)
    if zone_num < dzones then
      znum := ino.zone(zone_num);
      return (
        if znum = 0
        then 0
        else (util.bshift_l(znum, scale)+block_pos_in_zone));
    end if;

    -- if indirect
    declare
      function disk_read_zone_block is new read_block(zone_block_t);
    begin
      excess := zone_num - dzones;
      if excess < ino.n_indirs then -- single indirect
        znum := ino.zone(dzones);
      else -- double indirect
        znum := ino.zone(dzones+1);
        if znum = 0 then
          return 0;
        end if;
        excess := excess-ino.n_indirs; -- single indir doesn't count
        bnum := util.bshift_l(znum, scale);
        index := ((excess-1)/ino.n_indirs)+1;
        znum := disk_read_zone_block(bnum)(index); -- znum is zone for single
        excess := ((excess-1) mod ino.n_indirs)+1; -- index into single indir block
      end if;

      if znum = 0 then
        return 0;
      end if;
      bnum := util.bshift_l(znum, scale); -- bnum is block num of single indir
      znum := disk_read_zone_block(bnum)(excess);
      return (
        if znum = 0
        then 0
        else util.bshift_l(znum,scale)+block_pos_in_zone);
    end;
  end inode_fpos_to_bnum;

  function advance (inum : Natural; name : name_t) return Natural is
    -- given directory inum and component of path, look up component in the directory, find inode, and return its num
    -- 1. get inode 'inum'
    dir_ino : in_mem := get_inode(inum);
    pos : Natural := 1;
    bnum : Natural;
    function disk_read_dir_entry_block is new read_block(dir_entry_block_t);
    dir_entry_blk : dir_entry_block_t;
  begin
    if name(1) = Character'Val(0) then
      return inum;
    end if;
    -- 2. read direntry block in inum
    -- 3. look up 'name' in direntry block and return its inode number
    while pos <= dir_ino.size loop
      bnum := inode_fpos_to_bnum(dir_ino, pos);
      dir_entry_blk := disk_read_dir_entry_block(bnum);

      for dp in dir_entry_blk'Range loop
        if dir_entry_blk(dp).inode_num /= 0 and dir_entry_blk(dp).name = name then
          -- match
          tio.put_line("advance(): for last part '" & name & "' (in inode" & inum'Image & "), found dir entry block" & bnum'Image & " entry #" & dp'Image & " -> inode" & dir_entry_blk(dp).inode_num'Image);
          return dir_entry_blk(dp).inode_num;
        end if;
      end loop;

      pos := pos + const.block_size;
    end loop;
    -- not found
    return 0;
  end advance;

  -- given 'path', parse it as far as last dir.
  -- fetch inode for that dir into inode table, return its index.
  -- the final component is in 'final'
  function last_dir (path : path_t; procentry : proc.entry_t; final : out name_t) return Natural is
    function parse_next (path : path_t; cursor : in out Positive) return String is
      procedure skip_slashes is
      begin
        while path(cursor) = '/' and cursor+1 /= path'Last loop
          cursor := cursor+1;
        end loop;
        if cursor+1 = path'Last and path(cursor+1) = '/' then
          cursor := cursor+1;
        end if;
      end skip_slashes;
      startpos, endpos : Positive;
    begin
      skip_slashes;
      if cursor = path'Last or path(cursor) = Character'Val(0) then
        return "";
      end if;
      startpos := cursor;
      endpos := cursor;
      while endpos+1 /= path'Last and path(endpos+1) /= Character'Val(0) and path(endpos+1) /= '/' loop
        if path(endpos+1) /= '/' then
          endpos := endpos+1;
        end if;
      end loop;
      if endpos+1 = path'Last and path(endpos+1) /= '/' and path(endpos+1) /= Character'Val(0) then
        endpos := endpos+1;
      end if;
      cursor := (if (endpos = path'Last or path(endpos) = Character'Val(0)) then endpos else endpos+1);
      return path(startpos..endpos);
    end parse_next;

    inum : Natural := (if path(1) = '/' then procentry.rootdir else procentry.workdir);
    new_inum : Natural;
    cursor : Natural range path'Range := path'First;
    new_name : name_t;
  begin
    loop
      declare
        nn : String := parse_next(path, cursor);
      begin
        new_name := nn & (1..name_t'Last-nn'Length => Character'Val(0));
      end;
      if cursor = path'Last or path(cursor) = Character'Val(0) then
        -- if inode with inum is dir, normal exit
        -- otherwise, should error
        final := new_name;
        return inum;
      end if;

      -- there is more path, keep parsing
      new_inum := advance (inum, new_name);
      if new_inum = nil_inum then
        final := new_name;
        return nil_inum;
      end if;
      inum := new_inum;
    end loop;
  end last_dir;

  -- parse 'path' and return its inode number. analogous to 'eat_path'
  function path_to_inum (path : path_t; procentry : proc.entry_t) return Natural is
    final_compt : name_t;
    ldir_inum : Natural := last_dir(path, procentry, final_compt);
  begin
    if ldir_inum = 0 then
      return 0; -- couldn't open final directory
    end if;
    if final_compt = "" then
      return ldir_inum;
    end if;
    ldir_inum := advance(ldir_inum, final_compt);
    tio.put_line(path & ": inode" & ldir_inum'Image);
    return ldir_inum;
  end path_to_inum;

  procedure wipe_inode (ino : in out in_mem) is
  begin
    ino.size := 0;
    for i in 1..n_total_zones loop
      ino.zone(i) := 0;
    end loop;
  end wipe_inode;

  function alloc_inode return Natural is
    package imap is new bitmap (
      bitmap_blocks => super.imap_blocks,
      start_block => const.imap_start,
      block_size_bytes => const.block_size,
      disk => disk'Access,
      disk_acc => disk_acc'Access);
    imap_bit_num : imap.bit_nums := imap.alloc_bit(1); -- ideally, store search start in superblock and don't search whole bitmap (s_isearch)
    ino : in_mem;
  begin
    if imap_bit_num = 0 then
      return 0; -- no free inodes
    end if;
    -- set superblock i_search to b
    ino := get_inode(imap_bit_num);
    wipe_inode(ino);
    ino.nlinks := 0;
    ino.n_dzones := n_direct_zones;
    ino.n_indirs := n_indirects_in_block;
    put_inode(ino);
    return imap_bit_num;
  end alloc_inode;

  function alloc_zone (nearby_zone : Natural) return Natural is
    package imap is new bitmap (
      bitmap_blocks => super.imap_blocks,
      start_block => const.imap_start,
      block_size_bytes => const.block_size,
      disk => disk'Access,
      disk_acc => disk_acc'Access);

    package zmap is new bitmap (
      bitmap_blocks => super.zmap_blocks,
      start_block => imap.get_start_block+imap.size_in_blocks,
      block_size_bytes => const.block_size,
      disk => disk'Access,
      disk_acc => disk_acc'Access);

    b,bit : Natural;
  begin
    if nearby_zone = super.first_data_zone then
      bit := 1; -- should actually be s_zsearch for better efficiency
    else
      bit := nearby_zone-(super.first_data_zone); -- FIXME -1 or not?
    end if;
    b := zmap.alloc_bit(bit);
    if b = 0 then
      return 0; -- no space on device
    end if;
    -- save zsearch in superblock
    return super.first_data_zone + b; -- FIXME -1 or not?
  end alloc_zone;

  -- write a new zone into an inode
  procedure write_map (ino : in out in_mem; pos : Natural; new_zone : Natural) is
    scale : Natural := super.log_zone_size; -- for zone-block conversion
    zone : Natural := util.bshift_r(((pos+1)/const.block_size)-1, scale); -- relative zone num to insert
    zones : Natural := ino.n_dzones;
    nr_indirects : Natural := ino.n_indirs;
    bnum, excess, ind_ex, z, z1 : Natural;
    single, new_dbl, new_ind : Boolean;
  begin
    if zone < zones then -- position is in the inode itself
      ino.zone(zone) := new_zone;
      put_inode(ino);
      return;
    end if;
    -- position is not in inode
    excess := zone - zones;
    if excess < nr_indirects then -- position can be found via single indirect block
      z1 := ino.zone(zones);
      single := True;
    else -- position can be found via double indirect block
      z := ino.zone(zones+1);
      if z = 0 then -- have to create double indirect block
        z := alloc_zone(ino.zone(1));
        if z = 0 then
          return;
        end if;
        ino.zone(zones+1) := z;
        new_dbl := True;
      end if;
      -- z is now zone num for double indir block
      excess := excess - nr_indirects;  -- single indir doesn't count
      ind_ex := excess/nr_indirects;
      excess := excess mod nr_indirects;
      if ind_ex >= nr_indirects then
        return; -- too big
      end if;
      bnum := util.bshift_l(z, scale);
      if new_dbl then
        zero_block(bnum);
      end if;
      declare
        function read_zone_block is new read_block(zone_block_t);
        indir_block : zone_block_t := read_zone_block(bnum);
      begin
        z1 := indir_block(ind_ex);
      end;
      single := False;
    end if;

    -- z1 is now single indir zone, excess is index
    if z1 = 0 then
      -- create indirect block, store zone num in inode or dbl indir block
      z1 := alloc_zone (ino.zone(1));
      if single then
        ino.zone(zones) := z1;
      else
        declare
          function read_zone_block is new read_block(zone_block_t);
          indir_block : zone_block_t := read_zone_block(bnum);
          procedure write_zone_block is new write_block(zone_block_t);
        begin
          indir_block(ind_ex) := z1;
          write_zone_block(bnum, indir_block);
        end;
      end if;
      new_ind := True;
      if z1 = 0 then
        return; -- couldn't create single indirect
      end if;
    end if;

    -- z1 is indirect block's zone num
    bnum := util.bshift_l(z1, scale);
    if new_ind then
      zero_block(bnum);
    end if;
    declare
      function read_zone_block is new read_block(zone_block_t);
      indir_block : zone_block_t := read_zone_block(bnum);
      procedure write_zone_block is new write_block(zone_block_t);
    begin
      indir_block(excess) := new_zone;
      write_zone_block(bnum, indir_block);
    end;

    put_inode(ino);
  end write_map;

  -- zero a zone. 'pos' gives byte in first block to be zeroed
  procedure clear_zone (ino : in_mem; pos : Natural) is
    scale : Natural := super.log_zone_size;
    position,next,blo,bhi : Natural;
  begin
    if scale = 0 then -- block size and zone size are equal, not needed
      return;
    end if;

    zone_size := util.bshift_l(const.block_size, scale);
    position := (pos/zone_size) * zone_size;
    next := position + const.block_size;
    if next/zone_size /= position/zone_size then -- pos in last block of a zone, don't clear
      return;
    end if;
    blo := inode_fpos_to_bnum(ino, next);
    if blo = 0 then
      return;
    end if;
    bhi := util.bshift_l(util.bshift_r(blo, scale)+1, scale)-1;

    -- clear blocks between blo and bhi
    for i in blo..bhi loop
      zero_block(i);
    end loop;
  end clear_zone;

  function new_block (ino : in_mem; pos : Natural) return Natural is
    block_num : Natural := inode_fpos_to_bnum(ino, pos);
    base_block, zone_size : Natural;
    z : Natural;
    the_inode : in_mem := ino;
  begin
    if block_num /= no_block then
      zero_block(block_num);
      return block_num;
    else
      if the_inode.zone(1) = 0 then
        z := super.first_data_zone;
      else
        z := the_inode.zone(1);
      end if;
      z := alloc_zone(z);
      if z = 0 then
        return 0;
      end if;
      write_map(the_inode, pos, z);
      if pos /= the_inode.size then
        clear_zone(the_inode, pos);
      end if;

      base_block := util.bshift_l(z, super.log_zone_size);
      zone_size := util.bshift_l(const.block_size, super.log_zone_size);
      block_num := base_block + ((pos mod zone_size)/const.block_size);
      zero_block(block_num);
      return block_num;
   end if;
  end new_block;

  procedure add_entry (dir_num : Natural; str : name_t; inum : Natural) is
    dir_ino : in_mem := get_inode(dir_num);
    pos : Natural := 1;
    bnum : Natural;
    function disk_read_dir_entry_block is new read_block(dir_entry_block_t);
    procedure disk_write_dir_entry_block is new write_block(dir_entry_block_t);
    dir_entry_blk : dir_entry_block_t;

    hit,extended : Boolean := False;
    direct_size : Natural := direct'Size; -- fixme: remove
    old_slots : Natural := dir_ino.size/direct'Size;
    new_slots : Natural := 0;
    free_slot : Natural;
  begin
    while pos <= dir_ino.size loop
      bnum := inode_fpos_to_bnum(dir_ino, pos);
      dir_entry_blk := disk_read_dir_entry_block(bnum);

      for dp in dir_entry_blk'Range loop
        new_slots := new_slots+1;
        if new_slots > old_slots then -- not found, but room left in dir
          free_slot := dp;
          hit := True;
          tio.put_line("available direntry slot:" & free_slot'Image & ", block" & bnum'Image);
          exit;
        end if;

        if dir_entry_blk(dp).inode_num = 0 then
          free_slot := dp;
          hit := True;
          tio.put_line("available direntry slot:" & free_slot'Image & ", dir inode" & dir_num'Image & ", block" & bnum'Image);
          exit;
        end if;
      end loop;

      exit when hit;
      pos := pos + const.block_size;
    end loop;

    -- if directory full and no room left in last block, try to extend directory
    if not hit then
      new_slots := new_slots+1; -- increase directory size by 1 entry
      bnum := new_block(dir_ino, dir_ino.size);
      if bnum = 0 then
        return;
      end if;
      dir_entry_blk := disk_read_dir_entry_block(bnum);
      free_slot := 1;
      extended := True;
      tio.put_line("dir inode" & dir_num'Image & " extended, into block" & bnum'Image);
      tio.put_line("available direntry slot:" & free_slot'Image & ", dir inode" & dir_num'Image & ", block" & bnum'Image);
    end if;

    dir_entry_blk(free_slot).name := str & (1..name_t'Last-str'Length => Character'Val(0));
    dir_entry_blk(free_slot).inode_num := inum;
    tio.put_line("entry added: " & str & " ->" & inum'Image);
    disk_write_dir_entry_block(bnum, dir_entry_blk);
    if new_slots > old_slots then
      dir_ino.size := new_slots * direct'Size;
      put_inode(dir_ino);
      if extended then
        tio.put_line("dir was extended, writing dir inode" & dir_ino.num'Image & " to disk");
        put_inode(dir_ino);
      end if;
    end if;
  end add_entry;

  -- allocates new inode, creates entry for it at 'path', initializes it
  -- returns inode number, or 0 on error
  function new_inode (path_str : String; procentry : proc.entry_t) return Natural is
    path : path_t := path_str  & (1..path_t'Last-path_str 'Length => Character'Val(0));
    final_compt : name_t;
    ldir_inum : Natural := last_dir(path, procentry, final_compt);
    inum : Natural;
    ino : in_mem;
  begin
    if ldir_inum = 0 then
      return 0;
    end if;
    -- final dir is accessible, step into the last component
    inum := advance(ldir_inum, final_compt);
    if inum = 0 then
      -- good, doesn't exist - create it
      tio.put_line("creating last component '" & final_compt & "'");
      inum := alloc_inode;
      tio.put_line("allocated inode:" & inum'Image);
      if inum = 0 then
        return 0; -- couldn't create inode, out of inodes
      end if;
      ino := get_inode(inum);
      ino.nlinks := ino.nlinks+1;
      ino.zone(1) := 0; -- no zone
      put_inode(ino);
      add_entry(ldir_inum, final_compt, inum);
      return inum;
    else
      -- already exists or some problem
      tio.put_line("last component '"  & final_compt & "' of path already present, at inode" & inum'Image);
      return 0;
    end if;
  end new_inode;
end disk.inode;
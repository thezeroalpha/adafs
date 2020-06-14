package body disk.inode is

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
      while endpos+1 /= path'Last and path(endpos+1) /= '/' loop
        if path(endpos+1) /= '/' then
          endpos := endpos+1;
        end if;
      end loop;
      if endpos+1 = path'Last and path(endpos+1) /= '/' then
        endpos := endpos+1;
      end if;
      cursor := (if endpos = path'Last then endpos else endpos+1);
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
    return ldir_inum;
  end path_to_inum;
end disk.inode;

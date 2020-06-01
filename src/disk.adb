with types;
with inode;
with const;
with Ada.Direct_IO;
with Ada.Directories;
package body disk is
  function read_chunk (f_inode : inode.inode; position, offset, chunk : types.off_t; left : Positive) return types.byte_buf is
    buf : types.byte_buf (1..chunk); -- the user buffer
    dev : types.dev_t; -- device number
    block_num : Positive; -- physical block number
    block : types.b_data;
  begin
    block_num := read_map (f_inode, position); -- block number
    dev := f_inode.i_dev;
    block := rahead (f_inode, block_num, position, left); -- struct buf
    -- copy from disk into buffer

    -- TODO: just mocking the data
    buf := (others => 42);
    return buf;
  end read_chunk;

  function rahead (
    ino : inode.inode; -- inode for file to be read
    baseblock : Positive; -- block at current position
    position : types.off_t; -- position within file
    bytes_ahead : Positive -- bytes beyond position for immediate use
    ) return types.b_data is (get_block(ino.i_dev, baseblock));

  -- Given an inode and a position within the corresponding file, locate the
  -- block (not zone) number in which that position is to be found and return it.
  function read_map (f_inode : inode.inode; position : types.off_t) return Natural is
    -- bit shift functions
    function bshift_l (n, i : Positive) return Positive is (n*(2**i));
    function bshift_r (n, i : Positive) return Positive is (n/(2**i));

    scale : Integer := f_inode.i_sp.s_log_zone_size; -- for block => zone conversion
    block_pos : Positive := position/const.block_size; -- relative block number in file
    zone : Positive := bshift_r (block_pos, scale); -- position's zone
    boff : Positive := block_pos - bshift_l(zone, scale); -- relative block number within zone
    dzones : Positive := f_inode.i_ndzones;
    nr_indirects : Positive := f_inode.i_nindirs;

    z : types.zone_t;
    b : Positive; -- the physical block number to be returned
    bp : types.b_data;
    excess : Positive;
  begin
    -- if the position is in the inode itself (i.e. not indirect)
    if zone < dzones then
      z := f_inode.i_zone(zone);
      if z = 0 then -- no zone
        return 0; -- no block
      end if;
      b := (bshift_l (z, scale) + boff);
      return b;
    end if;

    -- if not, it must be indirect
    excess := zone - dzones;
    -- if single indirect
    if excess < nr_indirects then
      z := f_inode.i_zone (dzones);
    -- if double indirect
    else
      z := f_inode.i_zone (dzones+1);
      if z = 0 then -- no zone
        return 0; -- no block
      end if;
      excess := excess - nr_indirects; -- single indirect doesn't count
      b := bshift_l (z, scale);
      bp := get_block (f_inode.i_dev, b);
      z := rd_indir (bp, excess/nr_indirects);
      excess := excess mod nr_indirects;
    end if;

    -- z is zone num for single indirect block
    -- excess is index into it (the zone?)
    if z = 0 then -- no zone
      return 0; -- no block
    end if;
    b := bshift_l (z, scale); -- b is block num for single indirect
    bp := get_block (f_inode.i_dev, b); -- get single indrect block
    z := rd_indir (bp, excess); -- get the block
    if z = 0 then -- no zone
      return 0; -- no block
    end if;
    b := bshift_l (z, scale) + boff;
    return b;
  end read_map;

  function get_block (dev : types.dev_t; block_num : Positive) return types.b_data is
    pos : Positive;
    io_res : types.dev_io_res;
    r : Integer := 42; -- FIXME: what should this be?? do I even need it?
    eof : constant := -104;
  begin
    -- fancy cache stuff happens here but that comes at a later point
    -- for now, just do disk IO
    if dev /= 0 then
      pos := block_num * const.block_size;
      io_res := disk_read (dev, pos, const.block_size);
      if io_res.nbytes /= const.block_size then
        if r >= 0 then
          r := eof;
        end if;
        if r /= eof then
          -- FIXME: disk error!
               null;
        end if;
      end if;
    end if;
    return io_res.content;
  end get_block;

  procedure disk_init is
  begin
    disk_io.open (disk, disk_io.inout_file, disk_name);
  end disk_init;

  procedure disk_close is
  begin
    disk_io.close (disk);
  end disk_close;

  function disk_read (
    dev : types.dev_t; -- major-minor dev number
    pos : Positive; -- byte position
    nbytes : Natural -- how many bytes to transfer
    ) return types.dev_io_res is

    result : types.dev_io_res;
  begin
      -- for now just ignoring the dev number
      result.nbytes := 0;
    for i in pos..pos+nbytes loop
      disk_io.read (disk, result.content (result.nbytes+1), disk_io.count(i));
      result.nbytes := result.nbytes+1;
    end loop;
    return result;
  end disk_read;
end disk;


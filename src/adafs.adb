with Ada.Text_IO;
package body adafs is
  package tio renames Ada.Text_IO;
  procedure init is
    disk_init_ok : Boolean := dsk.init;
  begin
    if disk_init_ok then
      tio.put_line("Disk init correct.");
      declare
        function read_super is new dsk.read_block(superblock.superblock_t);
      begin
        super := read_super(2);
        if super.magic /= 16#2468# then
          tio.put_line("Magic number mismatch, disk likely not in MINIX format."); -- should do something more meaningful than this
          return;
        end if;
        inode.set_super(super);
      end;
      declare
        package imap is new bitmap (
          bitmap_blocks => super.imap_blocks,
          start_block => const.imap_start,
          block_size_bytes => const.block_size,
          disk => dsk.disk'Access,
          disk_acc => dsk.disk_acc'Access);
        package zmap is new bitmap (
          bitmap_blocks => super.zmap_blocks,
          start_block => const.imap_start+super.imap_blocks,
          block_size_bytes => const.block_size,
          disk => dsk.disk'Access,
          disk_acc => dsk.disk_acc'Access);
          t : Character := Character'Val(9);
      begin
        tio.put_line("sanity checks:");
        tio.put_line(t & "imap size" & imap.size_in_blocks'Image);
        tio.put_line(t & "first bit should be 1 (allocated), is" & imap.get_bit(1)'Image);
        tio.put_line(t & "second bit should be 0 (free), is" & imap.get_bit(2)'Image);
        tio.put_line(t & "zmap size" & zmap.size_in_blocks'Image);
        tio.put_line(t & "first bit should be 1 (allocated), is" & zmap.get_bit(1)'Image);
        tio.put_line(t & "second bit should be 0 (free), is" & zmap.get_bit(2)'Image);
      end;
    end if;
  end init;

  function open (path : String; pid : proc.tab_range) return fd_t is
    procentry : proc.entry_t := proc.get_entry (pid); -- fproc entry for the specific process
    fd : filp.fd_t := filp.get_free_fd (procentry.open_filps);
    filp_slot_num : filp.tab_num_t := filp.get_free_filp;
    inum : Natural;
  begin
    tio.put_line(Character'Val(10) & "== pid" & pid'Image & " opens " & path & " ==");
    inum := inode.path_to_inum (path & (1..inode.path_t'Last-path'Length => Character'Val(0)), procentry);
    if inum = 0 then
      tio.put_line ("couldn't open " & path);
      return filp.null_fd;
    end if;

    tio.put_line("Free fd:" & fd'Image);
    tio.put_line("Free filp slot:" & filp_slot_num'Image);

    filp.tab(filp_slot_num).count := 1;
    filp.tab(filp_slot_num).ino := inum;
    procentry.open_filps(fd) := filp_slot_num;
    proc.put_entry(pid, procentry);
    return fd;
  end open;

  function create (path : String; pid : proc.tab_range) return fd_t is
    procentry : proc.entry_t := proc.get_entry (pid);
    fd : filp.fd_t := filp.get_free_fd (procentry.open_filps);
    filp_slot_num : filp.tab_num_t := filp.get_free_filp;
    inum : Natural;
  begin
    tio.put_line(Character'Val(10) & "== pid" & pid'Image & " creates " & path & " ==");
    if fd = filp.null_fd then
      tio.put_line("no free fd available");
      return filp.null_fd;
    end if;
    inum := inode.new_inode (path, procentry);
    tio.put_line("created inode" & inum'Image);
    if inum = 0 then
      tio.put_line("Could not create " & path);
      return filp.null_fd;
    end if;
    tio.put_line("Free fd:" & fd'Image);
    tio.put_line("Free filp slot:" & filp_slot_num'Image);

    filp.tab(filp_slot_num).count := 1;
    filp.tab(filp_slot_num).ino := inum;
    procentry.open_filps(fd) := filp_slot_num;
    proc.put_entry(pid, procentry);
    return fd;
  end create;

  function write (fd : fd_t; num_bytes : Natural; data : dsk.data_buf_t; pid : proc.tab_range) return Natural is
    procentry : proc.entry_t := proc.get_entry(pid);
    filp_slot_num : filp.tab_num_t;
    inum, position, fsize, chunk, offset_in_blk : Natural;
    ino : inode.in_mem;
    nbytes : Natural := num_bytes;
  begin
    if fd = 0 then
      tio.put_line("cannot write to null fd");
      return 0;
    end if;
    filp_slot_num := procentry.open_filps(fd);
    if filp_slot_num = 0 then
      tio.put_line("cannot write, fd" & fd'Image & " refers to null filp slot");
      return 0;
    end if;
    if num_bytes = 0 then
      return 0;
    end if;
    position := filp.tab(filp_slot_num).pos;
    inum := filp.tab(filp_slot_num).ino;
    ino := inode.get_inode(inum);
    fsize := ino.size;
    if position > super.max_size - num_bytes then
      tio.put_line("cannot write, file would be too large");
      return 0;
    end if;
    if position > fsize then
      inode.clear_zone(ino, fsize);
    end if;

    -- split the transfer into chunks that don't span two blocks
    while nbytes /= 0 loop
      offset_in_blk := ((position-1) mod const.block_size)+1;
      chunk :=  (if nbytes < const.block_size-offset_in_blk then nbytes else const.block_size-offset_in_blk);
      inode.write_chunk(ino, position, offset_in_blk, chunk, nbytes, data(chunk..data'Last));
      nbytes := nbytes - chunk;
      position := position + chunk;
    end loop;
    if position > fsize then
      ino.size := position;
      inode.put_inode(ino);
    end if;
    filp.tab(filp_slot_num).pos := position;
    return nbytes;
  end write;
end adafs;


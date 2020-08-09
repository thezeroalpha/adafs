package body adafs.operations is
  procedure init is
  begin
    for pid in proc.tab'Range loop
        adafs.proc.init_entry(pid);
    end loop;
  end init;

  function open (path : String; pid : adafs.proc.tab_range) return adafs.filp.fd_t is
    procentry : adafs.proc.entry_t := adafs.proc.get_entry (pid); -- fproc entry for the specific process
    fd : adafs.filp.fd_t := adafs.filp.get_free_fd (procentry.open_filps);
    filp_slot_num : adafs.filp.tab_num_t;
    inum : Natural;
  begin
    adafs.filp.get_free_filp(filp_slot_num);
    inum := disk.inode.path_to_inum (path & (1..adafs.path_t'Last-path'Length => Character'Val(0)), procentry);
    if inum = 0 then
      return filp.null_fd;
    end if;

    filp.tab(filp_slot_num).count := 1;
    filp.tab(filp_slot_num).ino := inum;
    procentry.open_filps(fd) := filp_slot_num;
    proc.put_entry(pid, procentry);
    return fd;
  end open;

  procedure deinit is
  begin
    for pid in proc.tab'Range loop
      declare
        procentry : proc.entry_t := proc.get_entry(pid);
      begin
        for fd in procentry.open_filps'Range loop
          if procentry.open_filps(fd) /= 0 then
            close(fd, pid);
          end if;
        end loop;
        procentry := (is_null => True);
        proc.put_entry(pid, procentry);
      end;
    end loop;
  end deinit;

  procedure close (fd : adafs.filp.fd_t; pid : adafs.proc.tab_range) is
    procentry : proc.entry_t := proc.get_entry(pid);
    filp_slot_num : filp.tab_num_t;
  begin
    if fd = 0 then
      return;
    end if;
    filp_slot_num := procentry.open_filps(fd);
    if filp_slot_num = 0 then
      return;
    end if;
    filp.tab(filp_slot_num).count := filp.tab(filp_slot_num).count-1;
    procentry.open_filps(fd) := 0;
    proc.put_entry(pid, procentry);
  end close;

  function create (path : String; pid : adafs.proc.tab_range) return adafs.filp.fd_t is
    procentry : proc.entry_t := proc.get_entry (pid);
    fd : filp.fd_t := filp.get_free_fd (procentry.open_filps);
    filp_slot_num : filp.tab_num_t;
    inum : Natural;
  begin
    filp.get_free_filp(filp_slot_num);
    if fd = filp.null_fd then
      return filp.null_fd;
    end if;
    inum := disk.inode.new_inode (path, procentry);
    if inum = 0 then
      return filp.null_fd;
    end if;

    filp.tab(filp_slot_num).count := 1;
    filp.tab(filp_slot_num).ino := inum;
    procentry.open_filps(fd) := filp_slot_num;
    proc.put_entry(pid, procentry);
    return fd;
  end create;

  function write (fd : adafs.filp.fd_t; num_bytes : Natural; data : adafs.data_buf_t; pid : adafs.proc.tab_range) return Natural is
    procentry : proc.entry_t := proc.get_entry(pid);
    filp_slot_num : filp.tab_num_t;
    inum, position, fsize, chunk, offset_in_blk : Natural;
    ino : aliased adafs.inode.in_mem;
    nbytes : Natural := num_bytes;
    data_cursor : Natural := data'First;
  begin
    if fd = 0 then
      return 0;
    end if;
    filp_slot_num := procentry.open_filps(fd);
    if filp_slot_num = 0 then
      return 0;
    end if;
    if num_bytes = 0 then
      return 0;
    end if;
    position := filp.tab(filp_slot_num).pos;
    inum := filp.tab(filp_slot_num).ino;
    ino := disk.inode.get_inode(inum);
    fsize := ino.size;
    if position > disk.get_disk.super.max_size - num_bytes then
      return 0;
    end if;
    if position > fsize then
      disk.inode.clear_zone(ino, fsize);
    end if;

    -- split the transfer into chunks that don't span two blocks
    while nbytes /= 0 loop
      offset_in_blk := ((position-1) mod block_size)+1;
      chunk :=  (if nbytes < block_size-offset_in_blk+1 then nbytes else block_size-offset_in_blk+1);
      disk.inode.write_chunk(ino'access, position, offset_in_blk, chunk, nbytes, data(data_cursor..data_cursor+chunk-1));
      nbytes := nbytes - chunk;
      data_cursor := data_cursor+chunk;
      position := position + chunk;
    end loop;
    if position > fsize then
      ino := disk.inode.get_inode(inum);
      ino.size := position-1;
      disk.inode.put_inode(ino);
    end if;
    filp.tab(filp_slot_num).pos := position;
    return num_bytes-nbytes;
  end write;

  function read (fd : adafs.filp.fd_t; num_bytes : Natural; pid : adafs.proc.tab_range) return adafs.data_buf_t is
    procentry : proc.entry_t := proc.get_entry(pid);
    filp_slot_num : filp.tab_num_t;
    data_buf : adafs.data_buf_t(1..num_bytes) := (others => Character'Val(0));
    inum, position, fsize, chunk, offset_in_blk : Natural;
    nbytes : Natural := num_bytes;
    data_cursor : Natural := 1;
    ino : adafs.inode.in_mem;
  begin
    if fd = 0 then
      return data_buf;
    end if;
    filp_slot_num := procentry.open_filps(fd);
    if filp_slot_num = 0 then
      return data_buf;
    end if;
    if num_bytes = 0 then
      return data_buf;
    end if;
    position := filp.tab(filp_slot_num).pos;
    inum := filp.tab(filp_slot_num).ino;
    ino := disk.inode.get_inode(inum);
    fsize := ino.size;

    while nbytes /= 0 loop
      offset_in_blk := ((position-1) mod block_size)+1;
      chunk :=  (if nbytes < block_size-offset_in_blk+1 then nbytes else block_size-offset_in_blk+1);
      declare
        bytes_left : Natural := fsize-position+1;
      begin
        exit when position > fsize;
        if chunk > bytes_left then
          chunk := bytes_left;
        end if;
      end;
      data_buf(data_cursor..data_cursor+chunk-1) := disk.inode.read_chunk(ino, position, offset_in_blk, chunk, nbytes);
      nbytes := nbytes - chunk;
      data_cursor := data_cursor+chunk;
      position := position + chunk;
    end loop;
    filp.tab(filp_slot_num).pos := position;
    return data_buf;
  end read;


  function readdir (path : String; pid : adafs.proc.tab_range) return adafs.dir_buf_t is
    procentry : adafs.proc.entry_t := adafs.proc.get_entry (pid); -- fproc entry for the specific process
    inum : Natural;
    ino : adafs.inode.in_mem;
    null_buf : adafs.dir_buf_t(2..1);
  begin
    inum := disk.inode.path_to_inum (path & (1..adafs.path_t'Last-path'Length => Character'Val(0)), procentry);
    if inum = 0 then
      return null_buf;
    end if;
    ino := disk.inode.get_inode(inum);
    return disk.inode.read_dir(ino);
  end readdir;

  function lseek (fd : adafs.filp.fd_t; offset : Integer; whence : seek_whence_t; pid : adafs.proc.tab_range) return Natural is
    procentry : proc.entry_t := proc.get_entry(pid);
    filp_slot_num : filp.tab_num_t;
    pos : Natural;
  begin
    if fd = 0 then
      return 0;
    end if;
    filp_slot_num := procentry.open_filps(fd);
    if filp_slot_num = 0 then
      return 0;
    end if;
    case whence is
      when SEEK_SET =>
        pos := 0;
      when SEEK_CUR =>
        pos := filp.tab(filp_slot_num).pos;
      when SEEK_END =>
        declare
          inum : Natural := filp.tab(filp_slot_num).ino;
          ino : adafs.inode.in_mem := disk.inode.get_inode(inum);
        begin
          pos := ino.size;
        end;
    end case;

    if offset > 0 and pos+offset < pos then
      return 0;
    end if;
    if offset < 0 and pos + offset > pos then
      return 0;
    end if;
    pos := pos+offset;
    filp.tab(filp_slot_num).pos := pos;
    return pos;
  end lseek;


  function getattr (path : String; pid : adafs.proc.tab_range) return adafs.inode.attrs_t is
    procentry : adafs.proc.entry_t := adafs.proc.get_entry (pid); -- fproc entry for the specific process
    inum : Natural;
    ino : adafs.inode.in_mem;
  begin
    inum := disk.inode.path_to_inum (path & (1..adafs.path_t'Last-path'Length => Character'Val(0)), procentry);
    if inum = 0 then
      return (size => 0, nlinks => 0);
    end if;
    ino := disk.inode.get_inode(inum);
    return (size => ino.size, nlinks => ino.nlinks);
  end getattr;


  procedure unlink (path : String; pid : adafs.proc.tab_range; isdir : Boolean := False) is
    procentry : adafs.proc.entry_t := adafs.proc.get_entry(pid);
  begin
    if not isdir then
      disk.inode.unlink_file(path, procentry);
    else
      tio.put_line("Remove dir not implemented yet.");
      --  disk.inode.remove_dir(path, procentry);
    end if;
  end unlink;

end adafs.operations;

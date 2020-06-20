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
    tio.put_line(Character'Val(10) & "** pid" & pid'Image & " opens " & path & " **");
    adafs.filp.get_free_filp(filp_slot_num);
    inum := inode.path_to_inum (path & (1..adafs.inode.path_t'Last-path'Length => Character'Val(0)), procentry);
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
    tio.put_line(Character'Val(10) & "** pid" & pid'Image & " closes fd" & fd'Image & " **");
    if fd = 0 then
      tio.put_line("cannot close null fd");
      return;
    end if;
    filp_slot_num := procentry.open_filps(fd);
    if filp_slot_num = 0 then
      tio.put_line("cannot close fd" & fd'Image & ", is not open");
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
    tio.put_line(Character'Val(10) & "** pid" & pid'Image & " creates " & path & " **");
    filp.get_free_filp(filp_slot_num);
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

  function write (fd : adafs.filp.fd_t; num_bytes : Natural; data : adafs.data_buf_t; pid : adafs.proc.tab_range) return Natural is
    procentry : proc.entry_t := proc.get_entry(pid);
    filp_slot_num : filp.tab_num_t;
    inum, position, fsize, chunk, offset_in_blk : Natural;
    ino : adafs.inode.in_mem;
    nbytes : Natural := num_bytes;
    data_cursor : Natural := data'First;
  begin
    tio.put_line(Character'Val(10) & "** pid" & pid'Image & " writes" & num_bytes'Image & " bytes to fd" & fd'Image & " **");
    tio.put_line("data: " & String(data(data'First..num_bytes)));
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
    if position > dsk.get_disk.super.max_size - num_bytes then
      tio.put_line("cannot write, file would be too large");
      return 0;
    end if;
    if position > fsize then
      inode.clear_zone(ino, fsize);
    end if;

    -- split the transfer into chunks that don't span two blocks
    while nbytes /= 0 loop
      offset_in_blk := ((position-1) mod block_size)+1;
      chunk :=  (if nbytes < block_size-offset_in_blk then nbytes else block_size-offset_in_blk);
      inode.write_chunk(ino, position, offset_in_blk, chunk, nbytes, data(data_cursor..data_cursor+chunk-1));
      nbytes := nbytes - chunk;
      data_cursor := data_cursor+chunk;
      position := position + chunk;
    end loop;
    if position > fsize then
      ino := inode.get_inode(inum);
      ino.size := position-1;
      inode.put_inode(ino);
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
    data_cursor : Natural := 0;
    ino : adafs.inode.in_mem;
  begin
    tio.put_line(Character'Val(10) & "** pid" & pid'Image & " reads" & num_bytes'Image & " bytes from fd" & fd'Image & " **");
    if fd = 0 then
      tio.put_line("cannot read from null fd");
      return data_buf;
    end if;
    filp_slot_num := procentry.open_filps(fd);
    if filp_slot_num = 0 then
      tio.put_line("cannot read, fd" & fd'Image & " refers to null filp slot");
      return data_buf;
    end if;
    if num_bytes = 0 then
      return data_buf;
    end if;
    position := filp.tab(filp_slot_num).pos;
    inum := filp.tab(filp_slot_num).ino;
    ino := inode.get_inode(inum);
    fsize := ino.size;

    while nbytes /= 0 loop
      offset_in_blk := ((position-1) mod block_size)+1;
      chunk :=  (if nbytes < block_size-offset_in_blk then nbytes else block_size-offset_in_blk);
      declare
        bytes_left : Natural := fsize-position+1;
      begin
        exit when position > fsize;
        if chunk > bytes_left then
          chunk := bytes_left;
        end if;
      end;
      data_buf := inode.read_chunk(ino, position, offset_in_blk, chunk, nbytes);
      nbytes := nbytes - chunk;
      data_cursor := data_cursor+chunk-1;
      position := position + chunk;
    end loop;
    filp.tab(filp_slot_num).pos := position;
    return data_buf;
  end read;

  function lseek (fd : adafs.filp.fd_t; offset : Integer; whence : seek_whence_t; pid : adafs.proc.tab_range) return Natural is
    procentry : proc.entry_t := proc.get_entry(pid);
    filp_slot_num : filp.tab_num_t;
    pos : Natural;
  begin
    tio.put_line(Character'Val(10) & "** pid" & pid'Image & " seeks fd" & fd'Image & " **");
    if fd = 0 then
      tio.put_line("cannot seek in null fd");
      return 0;
    end if;
    filp_slot_num := procentry.open_filps(fd);
    if filp_slot_num = 0 then
      tio.put_line("cannot seek, fd" & fd'Image & " refers to null filp slot");
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
          ino : adafs.inode.in_mem := inode.get_inode(inum);
        begin
          pos := ino.size;
        end;
    end case;

    if offset > 0 and pos+offset < pos then
      tio.put_line("invalid position");
      return 0;
    end if;
    if offset < 0 and pos + offset > pos then
      tio.put_line("invalid position");
      return 0;
    end if;
    pos := pos+offset;
    tio.put_line("moving to byte" & pos'Image);
    filp.tab(filp_slot_num).pos := pos;
    return pos;
  end lseek;
end adafs.operations;

with const;

package body AdaFS is
  function Read (fd : Positive; nbytes : Positive; pid : Positive) return types.buffer is
    -- use pid to find fdtable
    proc_entry : proc.fproc := proc.get_entry (pid);
    -- use fd to index into found fdtable and find inode
    filp_entry : filp.filp := filp.get_entry (proc_entry.filp_tab, fd);
    f_inode : inode.inode := inode.get_entry (filp_entry.filp_ino);
    position : types.off_t := filp_entry.filp_pos;
    f_size : types.off_t := f_inode.i_size;

    data : types.buffer (1..nbytes);
    offset, chunk, bytes_left, buf_pos : types.off_t;
    num_bytes : Positive := nbytes;
  begin
    -- break up request to fit into blocks (1024 bytes each)
    -- copy to appropriate place in user buffer
    -- return number of bytes copied

    buf_pos := 1;

    while num_bytes /= 0 loop
      offset := position mod const.block_size; -- current offset in a block
      chunk := Integer'Min(num_bytes, const.block_size-offset);
      bytes_left := f_size-position;

      exit when position >= f_size;
      if chunk > bytes_left then
        chunk := bytes_left;
      end if;

      data (buf_pos..buf_pos+chunk) := disk.read_chunk(f_inode, position, offset, chunk, num_bytes);

      num_bytes := num_bytes - chunk;
      position := position + chunk;
      filp.update_pos(proc_entry.filp_tab, fd, position);
    end loop;
    return data;
  end Read;
end AdaFS;

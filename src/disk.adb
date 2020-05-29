package body disk is
  -- TODO: just mocking the data
  function read_chunk (f_inode : inode.inode; position, offset, chunk : types.off_t; nbytes : Positive) return types.buffer is
    buf : types.buffer (1..chunk) := (others => 42);
  begin
    return buf;
  end read_chunk;
end disk;


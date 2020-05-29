with types;
with inode;
package disk is
  function read_chunk (f_inode : inode.inode; position, offset, chunk : types.off_t; nbytes : Positive) return types.buffer;
end disk;

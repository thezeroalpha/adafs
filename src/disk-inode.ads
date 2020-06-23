with adafs.inode; use adafs.inode;
with adafs; use type adafs.data_buf_t;
with adafs.proc;
with disk.bitmap;
package disk.inode is
  function path_to_inum (path : adafs.path_t; procentry : adafs.proc.entry_t) return Natural;
  function new_inode (path_str : String; procentry : adafs.proc.entry_t) return Natural;
  function get_inode (num : Natural) return in_mem;
  procedure unlink_file (path_str : String; procentry : adafs.proc.entry_t);
  --  procedure remove_dir (path_str : String; procentry : adafs.proc.entry_t);
  procedure put_inode (ino : in_mem);
  procedure clear_zone (ino : in_mem; pos : Natural);

  procedure write_chunk(ino : in_mem; position, offset_in_blk, chunk, nbytes : Natural; data : adafs.data_buf_t);
  function read_chunk(ino : in_mem; position, offset_in_blk, chunk, nbytes : Natural) return adafs.data_buf_t;
  function read_dir(ino : in_mem) return adafs.dir_buf_t;
end disk.inode;

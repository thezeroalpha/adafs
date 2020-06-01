with types;
with inode;
with Ada.Direct_IO;
with Ada.Directories;
package disk is
  -- set up the disk (file)
  package disk_io is new Ada.Direct_IO (types.byte);
  disk_name : String := "disk.img";
  disk_size : Natural := Natural (Ada.Directories.Size (disk_name));
  disk : disk_io.file_type;

  function read_chunk (f_inode : inode.inode; position, offset, chunk : types.off_t; left : Positive) return types.byte_buf;
  function rahead (ino : inode.inode; baseblock : Positive; position : types.off_t; bytes_ahead : Positive) return types.b_data;
  function read_map (f_inode : inode.inode; position : types.off_t) return Natural;
  function bshift_l (n, i : Positive) return Positive is (n*(2**i));
  function bshift_r (n, i : Positive) return Positive is (n/(2**i));
  function get_block (dev : types.dev_t; block_num : Positive) return types.b_data;
  procedure disk_init;
  procedure disk_close;
  function disk_read (dev : types.dev_t; pos : Positive; nbytes : Natural) return types.dev_io_res;
  function rd_indir (bp : types.b_data; index : Integer) return types.zone_t is (42); -- TODO: mocked
end disk;

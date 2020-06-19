with Ada.Directories, Ada.Streams.Stream_IO, Ada.Text_IO, Ada.Finalization;
with adafs, adafs.inode, adafs.superblock;
generic
  filename_param : String;
package disk
  with SPARK_Mode
is
  package sio renames Ada.Streams.Stream_IO;
  package tio renames Ada.Text_IO;

  type disk_t is new Ada.Finalization.Controlled with
    record
      acc : access sio.file_type;
      filename : String(filename_param'Range);
      super : adafs.superblock.superblock_t;
    end record;
  function get_disk return access disk_t;

  size_bytes : Natural := Natural (Ada.Directories.Size(filename_param));
  size_in_bits : Natural := size_bytes*8;
  subtype file_position is Integer range 1..size_in_bits;

  size_blocks : Natural := size_bytes/adafs.block_size;
  subtype block_num is Natural range 0..size_blocks;
  no_block : constant block_num := 0;
  subtype disk_position is Integer range 1..size_blocks;

  n_inodes : Natural := adafs.inode.calc_num_inodes_for_blocks (size_blocks);
  n_zones : Natural := size_blocks;

  function block2pos (num : block_num) return file_position is (((num-1)*1024)+1);
  function pos2block (pos : file_position) return block_num is ((pos/adafs.block_size)+1);

  procedure go_block (num : block_num);

  generic
    type elem_t is private;
  function read_block (num : block_num) return elem_t;

  generic
    type elem_t is private;
  procedure write_block (num : block_num; e : elem_t);

  procedure zero_block (blk : block_num);
  procedure zero_disk;

  function is_reading return Boolean;
  function is_writing return Boolean;

  private
  stream_io_disk_ft : aliased sio.file_type; -- has to be global to allow access
  stream_io_disk_acc : sio.stream_access;
  procedure Initialize (disk : in out disk_t);
  procedure Finalize (disk : in out disk_t);

end disk;

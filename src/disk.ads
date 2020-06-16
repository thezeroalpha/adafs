with Ada.Directories, Ada.Streams.Stream_IO, Ada.Text_IO;
with const;
with inode_types;
generic
  filename : String;
package disk is
  package sio renames Ada.Streams.Stream_IO;
  package tio renames Ada.Text_IO;
  bootblock_num : constant := 1;
  superblock_num : constant := 2;

  size_bytes : Natural := Natural (Ada.Directories.Size(filename));
  size_in_bits : Natural := size_bytes*8;
  subtype file_position is Integer range 1..size_in_bits;

  size_blocks : Natural := size_bytes/const.block_size;
  subtype block_num is Natural range 0..size_blocks;
  no_block : constant block_num := 0;
  subtype disk_position is Integer range 1..size_blocks;

  n_inodes : Natural := inode_types.calc_num_inodes_for_blocks (size_blocks);
  n_zones : Natural := size_blocks;

  type data_buf_t is array (Natural range <>) of Character;

  function init return Boolean;
  procedure close;
  function name return String is (filename);

  function block2pos (num : block_num) return file_position is (((num-1)*1024)+1);
  function pos2block (pos : file_position) return block_num is ((pos/const.block_size)+1);

  procedure go_block (num : block_num);
  generic
    type elem_t is private;
  function read_block (num : block_num) return elem_t;

  generic
    type elem_t is private;
  procedure write_block (num : block_num; e : elem_t);

  procedure zero_block (blk : block_num);
  procedure zero_disk;

  disk : sio.FILE_TYPE;
  disk_acc : sio.STREAM_ACCESS;

  function is_reading return Boolean is (if sio."="(sio.mode(disk), sio.in_file) then True else False);
  function is_writing return Boolean is (if sio."="(sio.mode(disk), sio.out_file) then True else False);

end disk;

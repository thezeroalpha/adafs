package body inode_types is
  function calc_num_inodes_for_blocks (nblocks : Natural) return Natural is
    inode_max : constant := 65535;
    i : Natural := nblocks/3;
  begin
    i := (if nblocks >= 20000 then nblocks / 4 else i);
    i := (if nblocks >= 40000 then nblocks / 5 else i);
    i := (if nblocks >= 60000 then nblocks / 6 else i);
    i := (if nblocks >= 80000 then nblocks / 7 else i);
    i := (if nblocks >= 100000 then nblocks / 8 else i);
    i := i + num_per_block -1;
    i := i / (num_per_block*num_per_block);
    i := (if i > inode_max then inode_max else i);
    return i;
  end calc_num_inodes_for_blocks;
end inode_types;

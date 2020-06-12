with Ada.Text_IO;
package body adafs is
  package tio renames Ada.Text_IO;
  procedure init is
    disk_init_ok : Boolean := dsk.init;
  begin
    if disk_init_ok then
      tio.put_line("Disk init correct.");
      declare
        function read_super is new dsk.read_block(superblock.superblock_t);
      begin
        super := read_super(2);
        if super.magic /= 16#2468# then
          tio.put_line("Magic number mismatch, disk likely not in MINIX format."); -- should do something more meaningful than this
          return;
        end if;
      end;
      declare
        package imap is new bitmap (
          bitmap_blocks => super.imap_blocks,
          start_block => const.imap_start,
          block_size_bytes => const.block_size,
          disk => dsk.disk'Access,
          disk_acc => dsk.disk_acc'Access);
        package zmap is new bitmap (
          bitmap_blocks => super.zmap_blocks,
          start_block => const.imap_start+super.imap_blocks,
          block_size_bytes => const.block_size,
          disk => dsk.disk'Access,
          disk_acc => dsk.disk_acc'Access);
      begin
        tio.put_line("imap size" & imap.size_in_blocks'Image);
        tio.put_line("first bit should be 1 (allocated), is" & imap.get_bit(1)'Image);
        tio.put_line("second bit should be 1 (allocated), is" & imap.get_bit(2)'Image);
        tio.put_line("zmap size" & zmap.size_in_blocks'Image);
        tio.put_line("first bit should be 1 (allocated), is" & zmap.get_bit(1)'Image);
        tio.put_line("second bit should be 1 (allocated), is" & zmap.get_bit(2)'Image);
      end;
    end if;
  end init;

  function open (path : String; pid : proc.tab_range) return fd_t is
    procentry : proc.entry_t := proc.get_entry (pid); -- fproc entry for the specific process
    fd : filp.fd_t := filp.get_free_fd (procentry.open_filps);
    filp_slot_num : filp.tab_num_t := filp.get_free_filp;
    placeholder : constant := 7;
  begin
    tio.put_line("Free fd:" & fd'Image);
    tio.put_line("Free filp slot:" & filp_slot_num'Image);
    return placeholder;
  end open;
end adafs;


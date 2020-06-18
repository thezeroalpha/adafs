with disk;
with ada.text_io;
procedure main is
  package dsk is new disk ("disk.img");
begin
  ada.text_io.put_line("OK");
  ada.text_io.put_line("num inodes:" & dsk.get_disk.super.n_inodes'Image);
end main;

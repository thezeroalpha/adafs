with disk;
with adafs.operations;
with ada.text_io;
procedure main is
  package dsk is new disk ("disk.img");
  package fs is new adafs.operations(dsk);
begin
  ada.text_io.put_line("OK");
  ada.text_io.put_line("num inodes:" & fs.open'Image);
end main;

with Ada.Text_IO; use Ada.Text_IO;
with adafs, proc;
procedure main is
  fd1,fd2,fd3,fdx : Natural;
  pid : constant := 1;
begin
  put_line ("Main running");
  adafs.init;
  fd1 := adafs.open("/", pid);
  put_line("On first open, root dir assigned fd:" & fd1'Image);
  fd2 := adafs.open("/.", pid);
  put_line("On second open, root dir assigned fd:" & fd2'Image);
  fdx := adafs.open("/not_there", pid);
  put_line("nonexistent file /not_there assigned fd:" & fdx'Image);
  fd3 := adafs.open("/..", pid);
  put_line("On third open, root dir assigned fd:" & fd3'Image);
end main;


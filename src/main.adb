with Ada.Text_IO; use Ada.Text_IO;
with adafs, proc;
procedure main is
  fd1,fd2 : Natural;
  pid : constant := 1;
begin
  put_line ("Main running");
  adafs.init;
  fd1 := adafs.open("/", pid);
  fd2 := adafs.open("/", pid);
  put_line("On first open, root dir assigned fd:" & fd1'Image);
  put_line("On second open, root dir assigned fd:" & fd2'Image);
end main;


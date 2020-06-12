with Ada.Text_IO; use Ada.Text_IO;
with adafs, proc;
procedure main is
  fd : Natural;
  pid : constant := 1;
begin
  put_line ("Main running");
  adafs.init;
  fd := adafs.open("/sesame", pid);
end main;


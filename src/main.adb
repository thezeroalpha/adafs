with Ada.Text_IO; use Ada.Text_IO;
with adafs;
with proc;
procedure main is
  fd : Natural;
  pid : constant := 1;
begin
  put_line ("Main running");
  adafs.init;
  proc.new_entry(pid);
  fd := adafs.open("/sesame", pid);
end main;


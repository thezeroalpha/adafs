with Ada.Text_IO; use Ada.Text_IO;
with adafs, proc;
procedure main is
  fd1,fd2,fd3,fd4,fdx : Natural;
  pid : constant := 1;
begin
  put_line ("Main running, assuming fresh adafs image");
  adafs.init;
  fd1 := adafs.open("/", pid);
  put_line("On first open, root dir assigned fd:" & fd1'Image & " (should be 1)");
  fd2 := adafs.open("/.", pid);
  put_line("On second open, root dir assigned fd:" & fd2'Image & " (should be 2)");
  fdx := adafs.open("/sesame", pid);
  put_line("nonexistent file /sesame assigned fd:" & fdx'Image & " (should be 0, == null fd)");
  fd3 := adafs.open("/..", pid);
  put_line("On third open, root dir assigned fd:" & fd3'Image & " (should be 3)");
  fd4 := adafs.create("/sesame", pid);
  put_line("new file /sesame assigned fd:" & fd4'Image & " (should be 4)");
  fdx := adafs.create("/sesame", pid);
  put_line("creating file /sesame again, assigned fd:" & fdx'Image & " (should be 0, == null fd)");

  put_line("creating a few more files...");
  fdx := adafs.create("/file1", pid);
  fdx := adafs.create("/file2", pid);
  fdx := adafs.create("/file3", pid);
end main;


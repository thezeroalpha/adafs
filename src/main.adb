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

  put_line("#~ filling first zone");
  for i in 4..7 loop
    fdx := adafs.create("/file"&Integer'Image(i), pid);
  end loop;
  put_line("first file in next zone:");
  fdx := adafs.create("/newzone", pid);
  put_line("#~ filling second zone");
  for i in 9..14 loop
    fdx := adafs.create("/file"&Integer'Image(i), pid);
  end loop;
  fdx := adafs.create("/thirdzone", pid);

  for i in 16..19 loop
    fdx := adafs.create("/file"&Integer'Image(i), pid);
  end loop;

  put_line("#~ on first run, the creates below should fail." & Character'Val(10) & "#~ on second run, they should succeed.");
  for i in 20..21 loop
    fdx := adafs.create("/file"&Integer'Image(i), pid);
  end loop;
  fdx := adafs.create("/fourthzone", pid);

  fdx := adafs.open("/fourthzone", pid);
end main;


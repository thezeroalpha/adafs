with Ada.Text_IO; use Ada.Text_IO;
with adafs, proc;
procedure main is
  procedure write_data is
    fd : Natural;
    pid : constant := 1;
    n : Natural;
    data : adafs.dsk.data_buf_t := "Hello, World!";
  begin
    fd := adafs.create("/sesame", pid);
    put_line("new file /sesame assigned fd:" & fd'Image & " (should be 1)");
    n := adafs.write(fd, data'Length, data, pid);
    put_line("bytes written:" & n'Image);
  end write_data;
  procedure read_data is
    fd : Natural;
    pid : constant := 1;
  begin
    fd := adafs.open("/sesame", pid);
    put_line("file /sesame opened at fd:" & fd'Image & " (should be 1)");
  end read_data;
begin
  put_line ("Main running, assuming fresh adafs image");
  adafs.init;
  write_data;
  --  read_data;
end main;


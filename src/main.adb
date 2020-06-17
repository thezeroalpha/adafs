with Ada.Text_IO; use Ada.Text_IO;
with adafs, proc;
procedure main is
  fd1, fd2 : Natural;
  pid : constant := 1;
begin
  put_line ("Main running, assuming fresh adafs image");
  -- init disk
  adafs.init;
  -- create the file
  fd1 := adafs.create("/sesame", pid);

  -- write 13 bytes
  declare
    to_write : adafs.dsk.data_buf_t := "Hello, World!";
    n : Natural;
  begin
    n := adafs.write(fd1, to_write'Length, to_write, pid);
  end;

  adafs.deinit;

  adafs.init;
  fd2 := adafs.open("/sesame", pid);
  declare
    bytes_to_read : constant := 4;
    read_data : adafs.dsk.data_buf_t (1..bytes_to_read);
  begin
    read_data  := adafs.read(fd1, bytes_to_read, pid);
    put_line("read: " & String(read_data));
  end;

  adafs.deinit;

end main;


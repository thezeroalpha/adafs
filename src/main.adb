with Ada.Text_IO; use Ada.Text_IO;
with adafs, proc;
procedure main is
  fd1, fd2 : Natural;
  pid : constant := 1;
  pos : Natural := 1;
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
    pos := pos+n;
  end;

  pos := adafs.lseek(fd1, 1, adafs.SEEK_SET, pid);
  declare
    bytes_to_read : constant := 13;
    data : adafs.dsk.data_buf_t (1..bytes_to_read);
  begin
    data := adafs.read(fd1, bytes_to_read, pid);
    put_line("disk contains 'Hello, World?' (should be true) " & Boolean'(String(data) = "Hello, World!")'Image);
  end;

  -- seek to byte 5 ('o') and overwrite
  pos := adafs.lseek(fd1, 5, adafs.SEEK_SET, pid);
  declare
    to_write : adafs.dsk.data_buf_t := " yes.";
    n : Natural;
  begin
    n := adafs.write(fd1, to_write'Length, to_write, pid);
    pos := pos+n;
  end;

  -- seek to the end (after '!')
  pos := adafs.lseek(fd1, 0, adafs.SEEK_END, pid);
  declare
    to_write : adafs.dsk.data_buf_t := "it works!";
    n : Natural;
  begin
    n := adafs.write(fd1, to_write'Length, to_write, pid);
    pos := pos+n;
  end;

  -- seek 12 bytes backwards ('r')
  pos := adafs.lseek(fd1, -12, adafs.SEEK_CUR, pid);
  declare
    to_write : adafs.dsk.data_buf_t := "...";
    n : Natural;
  begin
    n := adafs.write(fd1, to_write'Length, to_write, pid);
    pos := pos+n;
  end;

  pos := adafs.lseek(fd1, 1, adafs.SEEK_SET, pid);
  declare
    bytes_to_read : constant := 21;
    data : adafs.dsk.data_buf_t (1..bytes_to_read);
  begin
    data := adafs.read(fd1, bytes_to_read, pid);
    put_line("disk changed? (should be true) " & Boolean'(String(data) = "Hell yes....it works!")'Image);
  end;
  adafs.deinit;

end main;


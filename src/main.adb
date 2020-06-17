with Ada.Text_IO; use Ada.Text_IO;
with adafs, proc;
procedure main is
  fd1, fd2 : Natural;
  pid : constant := 1;
begin
  put_line ("Main running, assuming fresh adafs image");
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

  -- read 2 bytes from current position, should be null
  declare
    bytes_to_read : constant := 2;
    read_data : adafs.dsk.data_buf_t (1..bytes_to_read);
  begin
    read_data  := adafs.read(fd1, bytes_to_read, pid);
    put_line("two bytes read are null?" & Boolean'(read_data(1) = (Character'Val(0)) and read_data(2) = (Character'Val(0)))'Image);
  end;

  -- close the file
  adafs.close(fd1, pid);


  -- try to read 1 byte from closed file, should fail
  declare
    bytes_to_read : constant := 1;
    read_data : adafs.dsk.data_buf_t (1..bytes_to_read);
  begin
    read_data  := adafs.read(fd1, bytes_to_read, pid);
    put_line("this read call should fail");
  end;

  -- try to write 1 byte to closed file, should fail
  declare
    to_write : adafs.dsk.data_buf_t := "F";
    n : Natural;
  begin
    n := adafs.write(fd1, to_write'Length, to_write, pid);
    put_line("this write call should fail");
  end;

  fd2 := adafs.open("/sesame", pid);
  put_line("first fd == second fd? (should be true) " & Boolean'(fd1 = fd2)'Image);

  -- read 13 bytes, should move cursor to pos 14
  declare
    bytes_to_read : constant := 13;
    read_data : adafs.dsk.data_buf_t (1..bytes_to_read);
  begin
    read_data := adafs.read(fd2, bytes_to_read, pid);
  end;

  -- read 1 byte, should return null and not move cursor beyond eof
  declare
    bytes_to_read : constant := 1;
    read_data : adafs.dsk.data_buf_t (1..bytes_to_read);
  begin
    read_data := adafs.read(fd2, bytes_to_read, pid);
    put_line("read a null byte? (should be true) " & Boolean'(read_data(1) = Character'Val(0))'Image);
  end;

  -- write more bytes
  declare
    to_write : adafs.dsk.data_buf_t := " GOOD STUFF";
    n : Natural;
  begin
    n := adafs.write(fd2, to_write'Length, to_write, pid);
  end;
  adafs.close(fd2, pid);

  fd1 := adafs.open("/sesame", pid);
  declare
    bytes_to_read : constant := 24;
    read_data : adafs.dsk.data_buf_t (1..bytes_to_read);
  begin
    read_data  := adafs.read(fd1, bytes_to_read, pid);
    put_line("read" & bytes_to_read'Image & " bytes from fd" & fd1'Image & ": " & String(read_data));
  end;
  adafs.close(fd1, pid);
end main;


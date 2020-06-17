pragma Assertion_Policy (Assert => Check);
with adafs;
with Ada.Text_IO;
procedure test is
  pid : constant := 1;
  pos : Natural := 1;

  procedure header (test_name : String) is begin
    Ada.Text_IO.Put_Line(Character'Val(10) & "== test " & test_name & " ==" & Character'Val(10));
  end header;

  procedure test_open_close is
    fd, fd2 : Natural;
  begin
    header("open & close");
    adafs.init;
    fd := adafs.open("/", pid);
    pragma assert(fd = 1, "file should open at fd 1");
    adafs.close(fd, pid);
    fd2 := adafs.open("/", pid);
    pragma assert(fd = fd2, "closed file should reopen at fd 1");
    adafs.deinit;
  end test_open_close;

  procedure test_create is
    fd, fdx : Natural;
    fname : String := "/sesame";
  begin
    header("create");
    adafs.init;

    -- create the file
    fd := adafs.create(fname, pid);
    pragma assert(fd = 1, "fd should be 1");

    -- try to create duplicate
    fdx := adafs.create(fname, pid);
    pragma assert(fdx = 0, "fd should be null");

    adafs.deinit;
  end test_create;

  procedure test_write is
    -- write 13 bytes
    hello_str : String := "Hello, World!";
    to_write : adafs.dsk.data_buf_t := adafs.dsk.data_buf_t(hello_str);
    fname : String := "/wfile";
    fd,n : Natural;
    pos : Natural := 1;
  begin
    header("write");
    adafs.init;
    fd := adafs.create(fname, pid);
    pragma assert(fd = 1, "fd should be 1");
    n := adafs.write(fd, to_write'Length, to_write, pid);
    pragma assert(n = to_write'Length);
    pos := pos+n;
    pragma assert(pos = to_write'Length+1);
    adafs.deinit;
  end test_write;

  procedure test_readwrite is
    hello_str : String := "Hello, World!";
    to_write : adafs.dsk.data_buf_t := adafs.dsk.data_buf_t(hello_str);
    bytes_to_read : constant := hello_str'Length;
    read_data : adafs.dsk.data_buf_t (1..bytes_to_read);
    fname : String := "/rwfile";
    fd,n : Natural;
    pos : Natural := 1;
  begin
    header("read & write");
    adafs.init;
    fd := adafs.create(fname, pid);
    pragma assert(fd = 1, "fd should be 1");
    n := adafs.write(fd, to_write'Length, to_write, pid);
    pragma assert(n = to_write'Length);
    pos := pos+n;
    pragma assert(pos = to_write'Length+1);
    adafs.close(fd, pid);
    fd := adafs.open(fname, pid);
    read_data := adafs.read(fd, bytes_to_read, pid);
    pragma assert(String(read_data) = hello_str, "start of disk should contain '" & hello_str & "'");
    adafs.deinit;
  end test_readwrite;

  procedure test_seek is
    -- write 13 bytes
    hello_str : String := "Hello, World!";
    to_write : adafs.dsk.data_buf_t := adafs.dsk.data_buf_t(hello_str);
    fname : String := "/seekfile";
    fd,n : Natural;
    pos : Natural := 1;
  begin
    header("seek");
    adafs.init;
    fd := adafs.create(fname, pid);
    pragma assert(fd = 1, "fd should be 1");
    n := adafs.write(fd, to_write'Length, to_write, pid);
    pragma assert(n = to_write'Length);
    pos := pos+n;
    pragma assert(pos = to_write'Length+1);
    -- seek to byte 5 ('o') and overwrite
    pos := adafs.lseek(fd, 5, adafs.SEEK_SET, pid);
    pragma assert(pos = 5);
    declare
      to_write : adafs.dsk.data_buf_t := " yes.";
      n : Natural;
    begin
      n := adafs.write(fd, to_write'Length, to_write, pid);
      pragma assert(n = to_write'Length);
      pos := pos+n;
    end;

    -- seek to the end (after '!')
    pos := adafs.lseek(fd, 0, adafs.SEEK_END, pid);
    pragma assert(pos = hello_str'Length);
    declare
      to_write : adafs.dsk.data_buf_t := "it works!";
      n : Natural;
    begin
      n := adafs.write(fd, to_write'Length, to_write, pid);
      pragma assert(n = to_write'Length);
    end;


    -- seek 12 bytes backwards ('r')
    pos := adafs.lseek(fd, -12, adafs.SEEK_CUR, pid);
    pragma assert(pos = 10);
    declare
      to_write : adafs.dsk.data_buf_t := "...";
      n : Natural;
    begin
      n := adafs.write(fd, to_write'Length, to_write, pid);
      pragma assert(n = to_write'Length);
    end;

    pos := adafs.lseek(fd, 1, adafs.SEEK_SET, pid);
    pragma assert(pos = 1);
    declare
      bytes_to_read : constant := 21;
      data : adafs.dsk.data_buf_t (1..bytes_to_read);
    begin
      data := adafs.read(fd, bytes_to_read, pid);
      pragma assert(String(data) = "Hell yes....it works!");
    end;

    adafs.deinit;
  end test_seek;

begin
  test_open_close;
  test_create;
  test_write;
  test_readwrite;
  test_seek;
end test;

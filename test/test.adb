pragma Assertion_Policy (Assert => Check);
with adafs.operations;
with disk;
with Ada.Text_IO;
procedure test is
  package dsk is new disk ("disk.img");
  package fs is new adafs.operations (dsk);

  pid : constant := 1;
  pos : Natural := 1;

  procedure header (test_name : String) is begin
    Ada.Text_IO.Put_Line(Character'Val(10) & "== test " & test_name & " ==" & Character'Val(10));
  end header;

  procedure test_open_close is
    fd, fd2 : Natural;
  begin
    header("open & close");
    fs.init;
    fd := fs.open("/", pid);
    pragma assert(fd = 1, "file should open at fd 1");
    fs.close(fd, pid);
    fd2 := fs.open("/", pid);
    pragma assert(fd = fd2, "closed file should reopen at fd 1");
    fs.deinit;
  end test_open_close;

  procedure test_create is
    fd, fdx : Natural;
    fname : String := "/sesame";
  begin
    header("create");
    fs.init;

    -- create the file
    fd := fs.create(fname, pid);
    pragma assert(fd = 1, "fd should be 1");

    -- try to create duplicate
    fdx := fs.create(fname, pid);
    pragma assert(fdx = 0, "fd should be null");

    fs.deinit;
  end test_create;

  procedure test_write is
    -- write 13 bytes
    hello_str : String := "Hello, World!";
    to_write : adafs.data_buf_t := adafs.data_buf_t(hello_str);
    fname : String := "/wfile";
    fd,n : Natural;
    pos : Natural := 1;
  begin
    header("write");
    fs.init;
    fd := fs.create(fname, pid);
    pragma assert(fd = 1, "fd should be 1");
    n := fs.write(fd, to_write'Length, to_write, pid);
    pragma assert(n = to_write'Length);
    pos := pos+n;
    pragma assert(pos = to_write'Length+1);
    fs.deinit;
  end test_write;

  procedure test_readwrite is
    hello_str : String := "Hello, World!";
    to_write : adafs.data_buf_t := adafs.data_buf_t(hello_str);
    bytes_to_read : constant := hello_str'Length;
    read_data : adafs.data_buf_t (1..bytes_to_read);
    fname : String := "/rwfile";
    fd,n : Natural;
    pos : Natural := 1;
  begin
    header("read & write");
    fs.init;
    fd := fs.create(fname, pid);
    pragma assert(fd = 1, "fd should be 1");
    n := fs.write(fd, to_write'Length, to_write, pid);
    pragma assert(n = to_write'Length);
    pos := pos+n;
    pragma assert(pos = to_write'Length+1);
    fs.close(fd, pid);
    fd := fs.open(fname, pid);
    read_data := fs.read(fd, bytes_to_read, pid);
    pragma assert(String(read_data) = hello_str, "start of disk should contain '" & hello_str & "'");
    fs.deinit;
  end test_readwrite;

  procedure test_seek is
    -- write 13 bytes
    hello_str : String := "Hello, World!";
    to_write : adafs.data_buf_t := adafs.data_buf_t(hello_str);
    fname : String := "/seekfile";
    fd,n : Natural;
    pos : Natural := 1;
  begin
    header("seek");
    fs.init;
    fd := fs.create(fname, pid);
    pragma assert(fd = 1, "fd should be 1");
    n := fs.write(fd, to_write'Length, to_write, pid);
    pragma assert(n = to_write'Length);
    pos := pos+n;
    pragma assert(pos = to_write'Length+1);
    -- seek to byte 5 ('o') and overwrite
    pos := fs.lseek(fd, 5, fs.SEEK_SET, pid);
    pragma assert(pos = 5);
    declare
      to_write : adafs.data_buf_t := " yes.";
      n : Natural;
    begin
      n := fs.write(fd, to_write'Length, to_write, pid);
      pragma assert(n = to_write'Length);
      pos := pos+n;
    end;

    -- seek to the end (after '!')
    pos := fs.lseek(fd, 0, fs.SEEK_END, pid);
    pragma assert(pos = hello_str'Length);
    declare
      to_write : adafs.data_buf_t := "it works!";
      n : Natural;
    begin
      n := fs.write(fd, to_write'Length, to_write, pid);
      pragma assert(n = to_write'Length);
    end;


    -- seek 12 bytes backwards ('r')
    pos := fs.lseek(fd, -12, fs.SEEK_CUR, pid);
    pragma assert(pos = 10);
    declare
      to_write : adafs.data_buf_t := "...";
      n : Natural;
    begin
      n := fs.write(fd, to_write'Length, to_write, pid);
      pragma assert(n = to_write'Length);
    end;

    pos := fs.lseek(fd, 1, fs.SEEK_SET, pid);
    pragma assert(pos = 1);
    declare
      bytes_to_read : constant := 21;
      data : adafs.data_buf_t (1..bytes_to_read);
    begin
      data := fs.read(fd, bytes_to_read, pid);
      pragma assert(String(data) = "Hell yes....it works!");
    end;

    fs.deinit;
  end test_seek;

  procedure test_readdir is
    fd : Natural;
    fname : String := "newfile";
  begin
    fs.init;
    header("readdir");
    fd := fs.create("/"&fname, pid);
    fs.close(fd, pid);
    fd := fs.open("/", pid);
    declare
      data : adafs.dir_buf_t := fs.readdir(fd, pid);
    begin
      pragma assert(data(data'Last) = (fname & (1..adafs.name_t'Last-fname'Length => adafs.nullchar)));
    end;
    fs.deinit;
  end test_readdir;
begin
  test_open_close;
  test_create;
  test_write;
  test_readwrite;
  test_seek;
  test_readdir;
end test;

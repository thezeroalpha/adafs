with Interfaces.C; use Interfaces.C;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with Ada.Text_IO; use Ada.Text_IO;
procedure AdaFs
is
  my_argc : int := 2;
  my_argv : chars_ptr_array := (New_String("dist/adafs"), New_String("/home/zeroalpha/adafs"));
  type Fuse_Args_T is record
    ArgC : int;
    ArgV : chars_ptr_array (0..size_t(my_argc));
    Allocated : int;
  end record;
  pragma Convention (C, Fuse_Args_T);

  Args : Fuse_Args_T := (my_argc, my_argv, 0);

  type Options_T is record
    filename : chars_ptr;
    contents : chars_ptr;
    show_help : int;
  end record;
  pragma Convention (C, Options_T);

  options : Options_T := (filename => New_String("hello"),
                          contents => New_String("Hello World!\n"),
                          show_help => 0);

begin
  Put_Line ("OK");
end AdaFs;

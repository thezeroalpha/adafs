package body proc is
  procedure new_entry (pid : tab_range) is
    new_entry : entry_t := (
      is_null => False,
      workdir => 1,
      rootdir => 1,
      filp_tab_num => 20);
  begin
    if tab(pid) = nil_entry then
      tab(pid) := new_entry;
      tio.put_line("Registered process" & pid'Image);
    else
      tio.put_line("Error: process" & pid'Image & " already registered.");
    end if;
  end new_entry;
end proc;

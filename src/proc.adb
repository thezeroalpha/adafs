package body proc is
  procedure put_entry (pid : tab_range; procentry : entry_t) is
  begin
    tab(pid) := procentry;
  end put_entry;
end proc;

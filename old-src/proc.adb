package body proc is
  procedure put_entry (pid : tab_range; procentry : entry_t) is
  begin
    tab(pid) := procentry;
  end put_entry;
  function get_entry (pid : tab_range) return entry_t is
  begin
    if tab(pid).is_null then
      tab(pid) := (is_null => False, workdir => 1, rootdir => 1, open_filps => (others => filp.null_fd));
    end if;
    return tab(pid);
  end get_entry;
end proc;

package body filp is
  function get_free_fd (open_filps : open_tab_t) return fd_t is
  begin
    for i in open_filps'Range loop
      if open_filps(i) = null_fd then
        return i;
      end if;
    end loop;
    return null_fd;
  end get_free_fd;

  function get_free_filp return tab_num_t is
  begin
    for f in tab'Range loop
      if tab(f).count = 0 then
        tab(f).pos := 1;
        return f;
      end if;
    end loop;
    return no_filp;
  end get_free_filp;
end filp;


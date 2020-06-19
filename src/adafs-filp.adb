package body adafs.filp
  with SPARK_Mode
is
  function get_free_fd (open_filps : open_tab_t) return fd_t is
  begin
    for i in open_filps'Range loop
      if open_filps(i) = null_fd then
        return i;
      end if;
    end loop;
    return null_fd;
  end get_free_fd;

  procedure get_free_filp (free_fd : out tab_num_t) is
  begin
    free_fd := no_filp;
    for f in tab_t'Range loop
      pragma Loop_Invariant (free_fd = no_filp);
      if tab(f).count = 0 then
        tab(f).pos := 1;
        free_fd := f;
        return;
      end if;
    end loop;
  end get_free_filp;
end adafs.filp;

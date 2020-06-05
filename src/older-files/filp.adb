package body filp is
  function get_entry (filp_entry_num : num; fd : Positive) return filp is
    proc_filp_tab : tab_t := tables (filp_entry_num);
    filp_entry : filp := proc_filp_tab (fd);
  begin
    return filp_entry;
  end get_entry;

  procedure update_pos (filp_entry_num : num; fd : Positive; pos : types.off_t) is
  begin
    tables(filp_entry_num)(fd).filp_pos := pos;
  end update_pos;
end filp;


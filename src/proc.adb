with Ada.Exceptions; use Ada.Exceptions;
package body proc is
  function get_entry (pid : Positive) return fproc is
    Unknown_Process : Exception;
  begin
    for p of tab loop
      if p.pid = pid then
        return p;
      end if;
    end loop;
    raise Unknown_Process with "Process " & pid'Image & " not in proc table.";
  end get_entry;
end proc;

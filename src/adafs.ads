with proc;
with filp;
with System.Storage_Elements;
package AdaFS is
  function Read (fd : Positive; buffer : System.Storage_Elements.Storage_Element; nbytes : Positive; pid : Positive) return Integer;
end AdaFS;

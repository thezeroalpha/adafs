with proc;
with filp;
with System.Storage_Elements;
with types;
with inode;
with disk;
package AdaFS is
  function Read (fd : Positive; nbytes : Positive; pid : Positive) return types.byte_buf;
end AdaFS;

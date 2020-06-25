package adafs
  with SPARK_Mode
is
  block_size : constant := 1024; -- bytes
  bootblock_num : constant := 1;
  superblock_num : constant := 2;
  imap_start : constant := 3;

  subtype name_t is String (1..20);
  subtype path_t is String (1..255); -- limits.h, PATH_MAX

  type data_buf_t is array (Positive range <>) of Character;
  type dir_buf_t is array (Positive range <>) of name_t;

  nullchar : Character := Character'Val(0);
  nlchar : Character := Character'Val(10);
  rchar : Character := Character'Val(13);

  -- TODO: need to come up with pre/post conditions for these functions to avoid overflow
  -- it's giving me weird errors...
  function bshift_l (n, i : Natural) return Natural is (n*(2**i)) with SPARK_Mode => Off;
  function bshift_r (n, i : Natural) return Natural is (n/(2**i)) with SPARK_Mode => Off;

end adafs;

with const;
package types is
  type mode_t is new Positive;
  subtype off_t is Positive;
  OPEN_MAX : constant := 20; -- open files a process may have
  type byte is mod 2**8;
  type byte_buf is array (Integer range <>) of types.byte;
  subtype block is Positive;
  subtype dev_t is Integer;
  subtype zone_t is Positive;
  type b_data is array (1..const.block_size) of byte;
  type b_ind is array (1..const.n_indirects) of zone_t;
  type dev_io_res is record
    nbytes : Natural;
    content : b_data;
  end record;
end types;

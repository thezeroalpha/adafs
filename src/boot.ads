with const;
package boot is
  type bootblock_t is array (1..const.block_size/4) of String (1..4);
end boot;

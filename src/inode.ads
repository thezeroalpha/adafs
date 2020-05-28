with types;
with const;
package inode is
  type nlink_t is new Integer;
  type uid_t is new Integer;
  type gid_t is new Character;
  type time_t is new Positive;
  type dev_t is new Integer;
  type ino_t is new Positive;
  type zone1_t is new Positive;

  V2_NR_TZONES : Integer := 10;
  type zone_t is array (1..V2_NR_TZONES) of Integer;

  type super_block is record
    s_ninodes : ino_t;            -- # usable inodes on the minor device
    s_nzones : zone1_t;           -- total device size, including bit maps etc
    s_imap_blocks : Integer;      -- # of blocks used by inode bit map
    s_zmap_blocks : Integer;      -- # of blocks used by zone bit map
    s_firstdatazone : zone1_t;    -- number of first data zone
    s_log_zone_size : Integer;    -- log2 of blocks/zone
    s_max_size : types.off_t;           -- maximum file size on this device
    s_magic : Integer;            -- magic number to recognize super-blocks
    s_pad : Integer;              -- try to avoid compiler-dependent padding
    s_zones : zone_t;             -- number of zones (replaces s_nzones in V2)
  end record;

  type inode is record
    i_mode : types.mode_t;      -- file type, protection, etc.
    i_nlinks : nlink_t;   -- how many links to this file
    i_uid : uid_t;        -- user id of the file's owner
    i_gid : gid_t;        -- group number
    i_size : types.off_t;       -- current file size in bytes
    i_atime : time_t;     -- time of last access (V2 only)
    i_mtime : time_t;     -- when was file data last changed
    i_ctime : time_t;     -- when was inode itself changed (V2 only)*/
    i_zone : zone_t;      -- zone numbers for direct, ind, and dbl ind

    -- these are not present on the disk
    i_dev : dev_t;           -- which device is the inode on
    i_num : ino_t;           -- inode number on its (minor) device
    i_count : Integer;       -- # times inode used; 0 means slot is free
    i_ndzones : Integer;     -- # direct zones (Vx_NR_DZONES)
    i_nindirs : Integer;     -- # indirect zones per indirect block
    i_sp : super_block;      -- pointer to super block for inode's device
    i_dirt : Character;      -- CLEAN or DIRTY
    i_pipe : Character;      -- set to I_PIPE if pipe
    i_mount : Character;     -- this bit is set if file mounted on
    i_seek : Character;      -- set on LSEEK, cleared on READ/WRITE
    i_update : Character;    -- the ATIME, CTIME, and MTIME bits are here
  end record;

  type tab_t is array (1..const.nr_inodes) of inode;
  type num is range 1..const.nr_inodes;
  tab : tab_t;

  function get_entry (inode_num : num) return inode is (tab (Integer(inode_num)));
end inode;

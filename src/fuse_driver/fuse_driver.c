#define FUSE_USE_VERSION 31
#include <fuse.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>

struct ada_attrs_t {
  int size;
  int nlinks;
};

extern void adainit (void);
extern void adafinal (void);
extern void ada_fsinit (void);
extern void ada_fsdeinit (void);

extern struct ada_attrs_t ada_getattr(const char *path, pid_t pid);
extern void ada_readdir(const char *path, char *contents[], int size, pid_t pid);
extern int ada_create(const char *path, pid_t pid);
extern int ada_open(const char *path, pid_t pid);
extern void ada_close(int fd, pid_t pid);
extern int ada_read(int fd, size_t nbytes, off_t offset, char *buf, pid_t pid);
extern int ada_write(int fd, size_t nbytes, off_t offset, const char *buf, pid_t pid);

void *myfs_init(struct fuse_conn_info *conn, struct fuse_config *cfg) {
  adainit();
  ada_fsinit();
  return NULL;
}
void myfs_destroy(void *private_data) {
  ada_fsdeinit();
  adafinal();
}

int myfs_getattr(const char *path, struct stat *st, struct fuse_file_info *finfo)
{
  pid_t pid = fuse_get_context()->pid;

  if (path[strlen(path)-1] == '/') {
    st->st_mode = S_IFDIR | 0755; // access rights and directory type
  } else {
    st->st_mode = S_IFREG | 0644; // access rights and regular file type
  }

  struct ada_attrs_t ada_attrs = ada_getattr(path, pid);
  if (ada_attrs.nlinks == 0) return -ENOENT;

  st->st_nlink = ada_attrs.nlinks;             // number of hard links, for directories this is at least 2
  st->st_size = ada_attrs.size;           // file size
  // user and group. we use the user's id who is executing the FUSE driver
  st->st_uid = getuid();
  st->st_gid = getgid();
  return 0;
}

int myfs_readdir(const char *path, void *buffer, fuse_fill_dir_t filler, off_t offset, struct fuse_file_info *fi, enum fuse_readdir_flags flags)
{
  pid_t pid = fuse_get_context()->pid;
  struct ada_attrs_t ada_attrs = ada_getattr(path, pid);
  if (ada_attrs.nlinks == 0) return -ENOENT;

  char *dir_contents[ada_attrs.nlinks];
  ada_readdir(path, dir_contents, ada_attrs.nlinks, pid);

  for (int i=0; i < ada_attrs.nlinks; i++)
    filler(buffer, dir_contents[i], NULL, 0, 0);
  return 0;
}

int myfs_create(const char *path, mode_t mode, struct fuse_file_info *finfo) {
  pid_t pid = fuse_get_context()->pid;
  int fd = ada_create(path, pid);
  if (fd == 0) return -EEXIST;
  finfo->fh = fd;
  return 0;
}

int myfs_open(const char *path, struct fuse_file_info *finfo) {
  pid_t pid = fuse_get_context()->pid;
  int fd = ada_open(path, pid);
  finfo->fh = fd;
  return 0;
}

int myfs_release(const char *path, struct fuse_file_info *finfo) {
  pid_t pid = fuse_get_context()->pid;
  int fd = finfo->fh;
  ada_close(fd, pid);
  finfo->fh = 0;
  return 0;
}

int myfs_read(const char *path, char *buf, size_t nbytes, off_t offset, struct fuse_file_info *finfo) {
  pid_t pid = fuse_get_context()->pid;
  int fd = finfo->fh;
  int bytes_read = ada_read(fd, nbytes, offset, buf, pid);
  return bytes_read;
}

int myfs_write(const char *path, const char *buf, size_t nbytes, off_t offset, struct fuse_file_info *finfo) {
  pid_t pid = fuse_get_context()->pid;
  int fd = finfo->fh;
  int bytes_written = ada_write(fd, nbytes, offset, buf, pid);
  return bytes_written;
}
static struct fuse_operations myfs_ops = {
  .init = myfs_init,
  .getattr = myfs_getattr,
  .readdir = myfs_readdir,
  .create = myfs_create,
  .open = myfs_open,
  .release = myfs_release,
  .read = myfs_read,
  .write = myfs_write,
  .destroy = myfs_destroy
};

char *devfile = NULL;

int main(int argc, char **argv)
{
  int i;

  // get the device or image filename from arguments
  for (i = 1; i < argc && argv[i][0] == '-'; i++);
  if (i < argc) {
    devfile = realpath(argv[i], NULL);
    memcpy(&argv[i], &argv[i+1], (argc-i) * sizeof(argv[0]));
    argc--;
  }
  // leave the rest to FUSE
  return fuse_main(argc, argv, &myfs_ops, NULL);
}

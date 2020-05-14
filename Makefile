FUSE_LIB=$(shell pkg-config fuse3 --cflags --libs)
MOUNTPOINT=$(HOME)/adafs
.PHONY: all clean run umount
all:
	mkdir -p dist obj
	gprbuild -P AdaFS.gpr -XFUSE_LIB="$(FUSE_LIB)"

run: all
	mkdir -p "$(MOUNTPOINT)"
	dist/adafs "$(MOUNTPOINT)"

umount:
	-umount "$(MOUNTPOINT)"

clean: umount
	gprclean -P AdaFS.gpr
	rmdir "$(MOUNTPOINT)"

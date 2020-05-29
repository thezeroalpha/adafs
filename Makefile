FUSE_LIB=$(shell pkg-config fuse3 --cflags --libs)
MOUNTPOINT=$(HOME)/adafs
.PHONY: all clean run umount
all:
	mkdir -p dist obj
	gprbuild -d -P AdaFS.gpr -XFUSE_LIB="$(FUSE_LIB)"

analyze:
	gprbuild -P AdaFS.gpr -d -gnatc -c -k

run: all
	mkdir -p "$(MOUNTPOINT)"
	dist/adafs "$(MOUNTPOINT)"

umount:
	-umount "$(MOUNTPOINT)"

clean: umount
	gprclean -P AdaFS.gpr
	rmdir "$(MOUNTPOINT)"

FUSE_LIB=$(shell pkg-config fuse3 --cflags --libs)
MOUNTPOINT=$(HOME)/adafs
PROJFILE=AdaFS.gpr

.PHONY: all clean run umount test

all: analyze
	mkdir -p dist obj
	gprbuild -g -P $(PROJFILE) -XFUSE_LIB="$(FUSE_LIB)"

fs: all
	dist/mkfs

analyze:
	@# (P)roject, (d)isplay progress, (f)orce recompilation, (c)ompile only
	@# gnats: check syntax
	@# gnatc: check semantics
	@# https://docs.adacore.com/gnat_ugn-docs/html/gnat_ugn/gnat_ugn/building_executable_programs_with_gnat.html
	gprbuild -P $(PROJFILE) -gnatc -d -f -gnata -c

test: fs
	dist/test
mem:
	gprbuild -P $(PROJFILE) -largs -lgmem

clean: umount
	gprclean -P $(PROJFILE)

FUSE_LIB=$(shell pkg-config fuse3 --cflags --libs)
MOUNTPOINT=$(HOME)/adafs
PROJFILE=AdaFS.gpr
FUSE_LOGFIFO=/tmp/fuse_log

.PHONY: all clean run umount test

all: analyze
	gprbuild -g -P $(PROJFILE) -XFUSE_LIB="$(FUSE_LIB)"

fs: all
	dist/mkfs

analyze:
	@# (P)roject, (d)isplay progress, (f)orce recompilation, (c)ompile only
	@# gnats: check syntax
	@# gnatc: check semantics
	@# https://docs.adacore.com/gnat_ugn-docs/html/gnat_ugn/gnat_ugn/building_executable_programs_with_gnat.html
	mkdir -p dist obj
	gprbuild -P $(PROJFILE) -gnatc -d -f -gnata -c -XFUSE_LIB="$(FUSE_LIB)"

benchmark: test/benchmark.c
	gcc -g test/benchmark.c -o dist/benchmark

mount: all
	-mkdir -p $(MOUNTPOINT)
	dist/fuse -s -f disk.img $(MOUNTPOINT)

prove:
	gnatprove -P "$(PROJFILE)" --report=fail
	@# might want to switch this for --report=statistics later

test: fs
	dist/test
mem:
	gprbuild -P $(PROJFILE) -largs -lgmem

clean: umount
	-@fusermount -u $(MOUNTPOINT)
	-@rmdir $(MOUNTPOINT)
	-@rm $(FUSE_LOGFIFO)
	gprclean -P $(PROJFILE)

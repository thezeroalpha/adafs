FUSE_LIB=$(shell pkg-config fuse3 --cflags --libs)
MOUNTPOINT=$(HOME)/adafs
PROJFILE=AdaFS.gpr
FUSE_LOGFIFO=/tmp/fuse_log

.PHONY: all clean run umount test

all: analyze
	mkdir -p dist obj
	gprbuild -g -P $(PROJFILE) -XFUSE_LIB="$(FUSE_LIB)"

fs: all
	dist/mkfs

fuse: clean all
	@mkfifo $(FUSE_LOGFIFO)
	@mkdir -p $(MOUNTPOINT)
	dist/fuse -d -s disk.img $(MOUNTPOINT) 1> $(FUSE_LOGFIFO) 2>&1 &
	@echo "Fuse running in the background"

analyze:
	@# (P)roject, (d)isplay progress, (f)orce recompilation, (c)ompile only
	@# gnats: check syntax
	@# gnatc: check semantics
	@# https://docs.adacore.com/gnat_ugn-docs/html/gnat_ugn/gnat_ugn/building_executable_programs_with_gnat.html
	gprbuild -P $(PROJFILE) -gnatc -d -f -gnata -c -XFUSE_LIB="$(FUSE_LIB)"

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

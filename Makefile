FUSE_LIB=$(shell pkg-config fuse3 --cflags --libs)
MOUNTPOINT=$(HOME)/adafs
PROJFILE=AdaFS.gpr

.PHONY: all clean run umount
all: analyze
	mkdir -p dist obj
	gprbuild -g -d -P $(PROJFILE) -XFUSE_LIB="$(FUSE_LIB)"

fs: all
	dist/mkfs


analyze:
	@# (P)roject, (d)isplay progress, (f)orce recompilation, (c)ompile only
	@# gnats: check syntax
	@# gnatc: check semantics
	@# https://docs.adacore.com/gnat_ugn-docs/html/gnat_ugn/gnat_ugn/building_executable_programs_with_gnat.html
	gprbuild -P $(PROJFILE) -d -f -gnats -c \
	  && gprbuild -P $(PROJFILE) -d -f -gnatc -gnats -c

mem:
	gprbuild -P $(PROJFILE) -largs -lgmem

run: all
	mkdir -p "$(MOUNTPOINT)"
	dist/adafs "$(MOUNTPOINT)"

umount:
	-umount "$(MOUNTPOINT)"

clean: umount
	gprclean -P $(PROJFILE)
	rmdir "$(MOUNTPOINT)"

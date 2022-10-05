# Makefile

ifdef install
PARAM = install
endif

all: lf4ed lfsearch lftmp lfhistory polygon luapanel highlight

lf4ed:
	cd _lf4ed_/build && $(MAKE) $(PARAM)

lfsearch:
ifndef install
	cd _lfsearch_/reader && $(MAKE)
endif
	cd _lfsearch_/build && $(MAKE) $(PARAM)

lftmp:
	cd _lftmp_/build && $(MAKE) $(PARAM)

lfhistory:
	cd _lfhistory_/build && $(MAKE) $(PARAM)

polygon:
	cd _polygon_/build && $(MAKE) $(PARAM)

luapanel:
	cd _luapanel_/build && $(MAKE) $(PARAM)

highlight:
	cd _highlight_/build && $(MAKE) $(PARAM)

.PHONY: all lf4ed lfsearch lftmp lfhistory polygon luapanel highlight

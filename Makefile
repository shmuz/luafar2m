# Makefile

install: PARAM=install

#  Note: plugin 'highlight' is intentionally not included in 'all'
#  because it is not suitable to most users.
all install: lf4ed lfsearch lftmp lfhistory polygon luapanel hlfviewer

lf4ed:
	cd _lf4ed_/build && $(MAKE) $(PARAM)

lfsearch:
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

hlfviewer:
	cd _hlfviewer_/build && $(MAKE) $(PARAM)

.PHONY: all lf4ed lfsearch lftmp lfhistory polygon luapanel highlight hlfviewer

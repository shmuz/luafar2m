# Makefile

all: luafar luamacro lf4ed lfsearch lftmp lfhistory polygon luapanel

luafar:
	cd luafar/src && $(MAKE)

luamacro:
	cd _luamacro_/build && $(MAKE)

lf4ed:
	cd _lf4ed_/build && $(MAKE)

lfsearch:
	cd _lfsearch_/build && $(MAKE)

lftmp:
	cd _lftmp_/build && $(MAKE)

lfhistory:
	cd _lfhistory_/build && $(MAKE)

polygon:
	cd _polygon_/build && $(MAKE)

luapanel:
	cd _luapanel_/build && $(MAKE)

.PHONY: all luafar luamacro lf4ed lfsearch lftmp lfhistory polygon luapanel

# Comment out a line to exclude a plugin from compilation
LF4ED     = 1
LFSEARCH  = 1
LFTMP     = 1
LFHISTORY = 1
POLYGON   = 1

noembed embed:
	cd luafar/src && $(MAKE)
ifdef LF4ED
	cd _lf4ed_/build     && $(MAKE) $@
endif
ifdef LFSEARCH
	cd _lfsearch_/build  && $(MAKE) $@
endif
ifdef LFTMP
	cd _lftmp_/build     && $(MAKE) $@
endif
ifdef LFHISTORY
	cd _lfhistory_/build && $(MAKE) $@
endif
ifdef POLYGON
	cd _polygon_/build   && $(MAKE) $@
endif

.PHONY: embed noembed

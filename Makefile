# Uncomment the next line to build plugin LF4Editor
LF4ED = 1

# Uncomment the next line to build plugin LFSearch
LFSEARCH = 1

# Uncomment the next line to build plugin LFTempPanel
LFTMP = 1

# Uncomment the next line to build plugin LFHistory
LFHISTORY = 1

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

.PHONY: embed noembed

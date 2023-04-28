# The partial Makefile shared between LuaFAR plugins

include ../../config.mak

# The following 4 variables should be defined by the including make file
CONFIG      ?=
FAR_EXPORTS ?=
LANG_GEN    ?=
PLUGNAME    ?=

C_SOURCE ?= $(FARSOURCE)/luafar/src/luaplug.c

ifdef FAR_EXPORTS
  EXPORTS = $(addprefix -DEXPORT_,$(FAR_EXPORTS))
endif

ifdef MINFARVERSION
  FARVERSION = -DMINFARVERSION=MAKEFARVERSION($(MINFARVERSION))
endif

LUAC        = luac5.1
PATH_PLUGIN = ../plug
GEN_METHOD  = -plain
MAKE_LANG   = $(LUAEXE) -epackage.path=[[$(LUA_SHARE)/?.lua]] $(LANG_GEN)

ifndef EMBED
  TRG = $(PLUGNAME).far-plug-wide
  OBJ = luaplug1.o
else
  TRG = $(PLUGNAME)_e.far-plug-wide
  OBJ = luaplug2.o linit.o
  FUNC_OPENLIBS ?= luafar_openlibs
endif

ifdef FUNC_OPENLIBS
  CFLAGS += -DFUNC_OPENLIBS=$(FUNC_OPENLIBS)
endif

ifdef SYS_ID
  CFLAGS += -DSYS_ID=$(SYS_ID)
endif

CFLAGS1 = $(CFLAGS) $(EXPORTS)
CFLAGS2 = $(CFLAGS1) -DEMBED

$(TRG): $(OBJ) $(LIBS)
	$(CC) -o $@ $^ $(LDFLAGS)
	mv -f $@ $(PATH_PLUGIN)
	cd $(PATH_PLUGIN) && $(MAKE_LANG)

# Since linit.c has changing prerequisites (sets of Lua files),
# that can not be specified in this makefile, it is better be
# rebuilt unconditionally; hence use of the double-colon rule.
linit.c::
	$(LUAEXE) -epackage.path=[[$(LUA_SHARE)/?.lua]]	\
	-erequire\(\'generate\'\)\([[$(CONFIG)]],[[$(LUA_SHARE)]],[[$@]],[[$(GEN_METHOD)]],[[$(LUAC)]]\)

luaplug1.o luaplug2.o: $(INC_FAR)/farplug-wide.h

luaplug1.o: $(C_SOURCE)
	$(CC) -c -o $@ $< $(CFLAGS1)

luaplug2.o: $(C_SOURCE)
	$(CC) -c -o $@ $< $(CFLAGS2)

install:
ifeq ("$(wildcard $(INSTALL_PREFIX)/bin/far2m)","")
	@echo Error: far2m installation is not found; exit 1
endif
	mkdir -p $(TRG_PLUG_LIB) $(TRG_PLUG_SHARE)
	cd ../plug && cp -f $(SRC_PLUG_LIB) $(TRG_PLUG_LIB)
	cd ../plug && cp -f $(SRC_PLUG_SHARE) $(TRG_PLUG_SHARE)
ifdef SRC_PLUG_DIRS
	cd ../plug && cp -rf $(SRC_PLUG_DIRS) $(TRG_PLUG_SHARE)
endif
	cp -rf $(LUA_SHARE) $(TRG_SHARE)

.PHONY:

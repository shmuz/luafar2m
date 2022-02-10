# The partial Makefile shared between LuaFAR plugins

include ../../config.mak

# The following 4 variables should be defined by the including make file
CONFIG      ?=
FAR_EXPORTS ?=
LANG_LUA    ?=
PLUGNAME    ?=

C_SOURCE ?= $(PATH_LUAFAR)/src/luaplug.c

ifdef FAR_EXPORTS
  EXPORTS = $(addprefix -DEXPORT_,$(FAR_EXPORTS))
endif

ifdef MINFARVERSION
  FARVERSION = -DMINFARVERSION=MAKEFARVERSION($(MINFARVERSION))
endif

LUAC        = luac5.1
PATH_PLUGIN = ../plug
GEN_METHOD  = -plain
MAKE_LANG   = $(LUAEXE) -epackage.path=[[$(LUA_SHARE)/?.lua]] $(LANG_LUA)

ifeq ($(DIRBIT),64)
  TRG_N = $(PLUGNAME)-x64.far-plug-wide
  TRG_E = $(PLUGNAME)_e-x64.far-plug-wide
else
  TRG_N = $(PLUGNAME).far-plug-wide
  TRG_E = $(PLUGNAME)_e.far-plug-wide
endif

CFLAGS1 = $(CFLAGS) $(EXPORTS)
CFLAGS2 = $(CFLAGS1) -DFUNC_OPENLIBS=luafar_openlibs

OBJ_N   = luaplug1.o
OBJ_E   = luaplug2.o linit.o
LIBS    = ../../$(LUAFARDLL)

embed: $(TRG_E)
	mv -f $< $(PATH_PLUGIN)
	cd $(PATH_PLUGIN) && $(MAKE_LANG)

noembed: $(TRG_N)
	mv -f $< $(PATH_PLUGIN)
	cd $(PATH_PLUGIN) && $(MAKE_LANG)

$(TRG_N): $(OBJ_N) $(LIBS)
	$(CC) -o $@ $^ $(LDFLAGS)

$(TRG_E): $(OBJ_E) $(LIBS)
	$(CC) -o $@ $^ $(LDFLAGS)

# Since linit.c has changing prerequisites (sets of Lua files),
# that can not be specified in this makefile, it is better be
# rebuilt unconditionally; hence use of the double-colon rule.
linit.c::
	$(LUAEXE) -epackage.path=[[$(LUA_SHARE)/?.lua]]	\
	-erequire\(\'generate\'\)\([[$(CONFIG)]],[[$(LUA_SHARE)]],[[$@]],[[$(GEN_METHOD)]],[[$(LUAC)]]\)

luaplug1.o: $(C_SOURCE)
	$(CC) -c -o $@ $< $(CFLAGS1)

luaplug2.o: $(C_SOURCE)
	$(CC) -c -o $@ $< $(CFLAGS2)

.PHONY: noembed embed

# LuaFAR for Editor: Makefile

FAR_EXPORTS = CONFIGUREW  EXITFARW  OPENPLUGINW  PROCESSEDITOREVENTW  \
              PROCESSEDITORINPUTW  PROCESSVIEWEREVENTW
include ../../../_luafar_/config.mak

LUAC        = $(LUADLLPATH)/luac.exe
PATH_PLUGIN = ..
PATH_SCRIPT = $(PATH_PLUGIN)/script
SCRIPTS     = luaplug.lua config.lua expression.lua wrap.lua
GEN_METHOD  = -plain
MAKE_LANG   = $(LUAEXE) -epackage.path=[[$(LUA_SHARE)/?.lua]] lf4ed_lang.lua

CONFIG      = lf4ed.cfg

ifeq ($(DIRBIT),64)
  TRG1      = lf4ed-x64.far-plug-wide
  TRG2      = lf4ed_e-x64.far-plug-wide
else
  TRG1      = lf4ed.far-plug-wide
  TRG2      = lf4ed_e.far-plug-wide
endif

CFLAGS1     = $(CFLAGS) -DBUILD_STATIC $(EXPORTS)
CFLAGS2     = $(CFLAGS1) -DFUNC_OPENLIBS=luafar_openlibs

OBJ1        = luaplug1.o
OBJ2        = luaplug2.o linit.o

LIBS1       = $(PATH_INSTALL)/$(LUAFARDLL)
LIBS2       = $(LIBS1)

#-----------------------------------------------------------------------------

embed: $(TRG2)
	mv -f $< $(PATH_PLUGIN)
	cd $(PATH_PLUGIN) && $(MAKE_LANG)

noembed: $(TRG1)
	mv -f $< $(PATH_PLUGIN)
	cd $(PATH_PLUGIN) && $(MAKE_LANG)

$(TRG1): $(OBJ1) $(LIBS1)
	$(CC) -o $@ $^ $(LDFLAGS)

$(TRG2): $(OBJ2) $(LIBS2)
	$(CC) -o $@ $^ $(LDFLAGS)

# Since linit.c has changing prerequisites (sets of Lua files),
# that can not be specified in this makefile, it is better be
# rebuilt unconditionally; hence use of the double-colon rule.
linit.c::
	$(LUAEXE) -epackage.path=[[$(LUA_SHARE)/?.lua]]	\
	-erequire\(\'generate\'\)\([[$(CONFIG)]],[[$(LUA_SHARE)]],[[$@]],[[$(GEN_METHOD)]],[[$(LUAC)]]\)

luaplug1.o: $(PATH_LUAFARSRC)/luaplug.c
	$(CC) -c -o $@ $< $(CFLAGS1)

luaplug2.o: $(PATH_LUAFARSRC)/luaplug.c
	$(CC) -c -o $@ $< $(CFLAGS2)

cleanplug:
	cd $(PATH_PLUGIN) && del *.dll *.d $(SCRIPTS) farcolor.lua farkeys.lua

cleansrc:
	del *.o *.dll luac.out linit.c

clean:
	$(MAKE) cleanplug cleansrc

.PHONY: noembed embed clean cleanplug cleansrc


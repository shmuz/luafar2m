# LuaFAR for Editor: Makefile

FAR_EXPORTS = CLOSEPLUGIN  CONFIGURE  EXITFAR  GETFINDDATA  GETOPENPLUGININFO \
              OPENFILEPLUGIN  OPENPLUGIN  PROCESSEVENT  PROCESSKEY  PUTFILES  \
              SETDIRECTORY  SETFINDLIST
include ../../config.mak

LUAC        = $(LUADLLPATH)/luac.exe
PATH_PLUGIN = ../plug
GEN_METHOD  = -plain
MAKE_LANG   = $(LUAEXE) -epackage.path=[[$(LUA_SHARE)/?.lua]] tmpp_lang.lua
CONFIG      = tmppanel.cfg

ifeq ($(DIRBIT),64)
  TRG_N = lftmp-x64.far-plug-wide
  TRG_E = lftmp_e-x64.far-plug-wide
else
  TRG_N = lftmp.far-plug-wide
  TRG_E = lftmp_e.far-plug-wide
endif

CFLAGS1 = $(CFLAGS) -DBUILD_STATIC $(EXPORTS)
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

luaplug1.o: $(PATH_LUAFARSRC)/luaplug.c
	$(CC) -c -o $@ $< $(CFLAGS1)

luaplug2.o: $(PATH_LUAFARSRC)/luaplug.c
	$(CC) -c -o $@ $< $(CFLAGS2)

.PHONY: noembed embed

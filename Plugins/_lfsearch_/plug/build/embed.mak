#  Makefile for a FAR plugin containing embedded Lua modules and/or scripts.
#  The target embeds Lua scripts and has dependencies on Lua
#  and LuaFAR DLLs.

FAR_EXPORTS = OPENPLUGINW
include ../../../_luafar_/config.mak

TRG         = lfsearch-x$(DIRBIT).far-plug-wide
LUAC        = $(PATH_EXE)/luac.exe
GEN_METHOD  = -plain
CONFIG      = embed.cfg
C_INIT      = $(TRG)_init.c
OBJ_INIT    = $(TRG)_init.o
OBJ_PLUG    = $(TRG)_plug.o
MYCFLAGS    = -DFUNC_OPENLIBS=luafar_openlibs $(EXPORTS)

OBJ         = $(OBJ_INIT) $(OBJ_PLUG)
LIBS        = $(LUADLL) $(LUAFARDLL)

all: $(TRG)

$(TRG): $(OBJ) $(LIBS)
	$(CC) -o $@ $^ $(LDFLAGS)

$(OBJ_PLUG): $(PATH_LUAFARSRC)/luaplug.c
	$(CC) -c $< -o $@ $(CFLAGS)

# Since $(C_INIT) has changing prerequisites (sets of Lua files),
# that can not be specified in this makefile, it is better be
# rebuilt unconditionally; hence use of the double-colon rule.
$(C_INIT)::
	$(LUAEXE) -epackage.path=[[$(LUA_SHARE)/?.lua]]	\
	-erequire\(\'generate\'\)\([[$(CONFIG)]],[[$(LUA_SHARE)]],[[$@]],[[$(GEN_METHOD)]],[[$(LUAC)]]\)

clean:
	del *.o *.dll luac.out $(C_INIT)

.PHONY: clean all

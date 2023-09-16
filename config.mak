# User-configurable settings
# ---------------------------

# Location of far2m source tree
FARSOURCE = $(HOME)/far2m

INC_LUA = /usr/include/luajit-2.1
# INC_LUA = /usr/include/lua5.1

LUAEXE = luajit
# LUAEXE = lua5.1

# Location of lua_share
LUA_SHARE = $(FARSOURCE)/luafar/lua_share

# Settings below do not usually require editing
# ----------------------------------------------

INC_FAR = $(FARSOURCE)/far/far2sdk

CFLAGS = -O2 -Wall -Wno-unused-function -fvisibility=hidden \
         -I$(INC_FAR) -I$(INC_LUA) -fPIC $(MYCFLAGS)

LDFLAGS = -shared -fPIC $(MYLDFLAGS)

### Install section
INSTALL_PREFIX ?= /usr/local
TRG_LIB   = $(INSTALL_PREFIX)/lib/far2m/Plugins/luafar
TRG_SHARE = $(INSTALL_PREFIX)/share/far2m/Plugins/luafar

TRG_PLUG_LIB = $(TRG_LIB)/$(PLUGNAME)/plug
TRG_PLUG_SHARE = $(TRG_SHARE)/$(PLUGNAME)/plug

SRC_PLUG_LIB ?= $(PLUGNAME).far-plug-wide

SRC_PLUG_SHARE ?= *.lua *.lng *.hlf

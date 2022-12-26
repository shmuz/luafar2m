# User-configurable settings
# ---------------------------

# Far2l source tree
FARSOURCE = $(HOME)/far2l

# Set USE_LUAJIT=0 to use Lua5.1 rather than LuaJIT
USE_LUAJIT = 1

# Settings below do not usually require editing
# ----------------------------------------------

INC_FAR = $(FARSOURCE)/far2l/far2sdk
INC_WIN = $(FARSOURCE)/WinPort

ifneq ($(USE_LUAJIT),1)
  INC_LUA = /usr/include/lua5.1
  LUAEXE  = lua
else
  INC_LUA = /usr/include/luajit-2.1
  LUAEXE  = luajit
endif

SRC_LUAFAR = ../..
LUA_SHARE  = $(SRC_LUAFAR)/lua_share
LUAFARDLL  = luafar2l.so

CC     = gcc
CFLAGS = -O2 -Wall -Wno-unused-function -fvisibility=hidden \
         -I$(INC_FAR) -I$(INC_WIN) -I$(INC_LUA) \
         -fPIC $(MYCFLAGS)

LDFLAGS = -shared -fPIC $(MYLDFLAGS)

### Install section
INSTALL_PREFIX ?= /usr/local
TRG_LIB   = $(INSTALL_PREFIX)/lib/far2l/Plugins/luafar
TRG_SHARE = $(INSTALL_PREFIX)/share/far2l/Plugins/luafar

TRG_PLUG_LIB = $(TRG_LIB)/$(PLUGNAME)/plug
TRG_PLUG_SHARE = $(TRG_SHARE)/$(PLUGNAME)/plug

SRC_LF_INIT = $(SRC_LUAFAR)/luafar_init.lua

SRC_PLUG_LIB ?= $(PLUGNAME).far-plug-wide

SRC_PLUG_SHARE ?= *.lua *.lng *.hlf

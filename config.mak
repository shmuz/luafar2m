# User-configurable settings
# ---------------------------

# Far2m source tree
FARSOURCE = $(HOME)/far2m

# Set USE_LUAJIT=0 to use Lua5.1 rather than LuaJIT
USE_LUAJIT = 1

# Settings below do not usually require editing
# ----------------------------------------------

INC_FAR = $(FARSOURCE)/far/far2sdk
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

CC     = gcc
CFLAGS = -O2 -Wall -Wno-unused-function -fvisibility=hidden \
         -I$(INC_FAR) -I$(INC_WIN) -I$(INC_LUA) -fPIC $(MYCFLAGS)

ifdef SETPACKAGEPATH
  CFLAGS += -DSETPACKAGEPATH
endif

LDFLAGS = -shared -fPIC $(MYLDFLAGS)

### Install section
INSTALL_PREFIX ?= /usr/local
TRG_LIB   = $(INSTALL_PREFIX)/lib/far2m/Plugins/luafar
TRG_SHARE = $(INSTALL_PREFIX)/share/far2m/Plugins/luafar

TRG_PLUG_LIB = $(TRG_LIB)/$(PLUGNAME)/plug
TRG_PLUG_SHARE = $(TRG_SHARE)/$(PLUGNAME)/plug

SRC_PLUG_LIB ?= $(PLUGNAME).far-plug-wide

SRC_PLUG_SHARE ?= *.lua *.lng *.hlf

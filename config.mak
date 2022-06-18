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
  LIB_LUA = -llua5.1
  LUAEXE  = lua
else
  INC_LUA = /usr/include/luajit-2.1
  LIB_LUA = -lluajit-5.1
  LUAEXE  = luajit
  JITCFLAG = -DUSE_LUAJIT
endif

LUA_SHARE   = ../../lua_share
LUAFARDLL   = luafar2l.so

DIRBIT = 64
CC     = gcc
CFLAGS = -O2 -Wall -Wno-unused-function -fvisibility=hidden \
         -I$(INC_FAR) -I$(INC_WIN) -I$(INC_LUA) \
         -m$(DIRBIT) -fPIC $(JITCFLAG) $(MYCFLAGS)

# LDFLAGS = -shared -m$(DIRBIT) -fPIC -Wl,-z,defs $(LIB_LUA) $(MYLDFLAGS)
LDFLAGS = -shared -m$(DIRBIT) -fPIC $(LIB_LUA) $(MYLDFLAGS)

# User-configurable settings
# ---------------------------

FARSOURCE  = $(HOME)/far2l

# Settings below do not usually require editing
# ----------------------------------------------

INC_FAR = $(FARSOURCE)/far2l/far2sdk
INC_WIN = $(FARSOURCE)/WinPort
INC_LUA = /usr/include/lua5.1

LUA_SHARE   = ../../lua_share
LUAFARDLL   = luafar2l.so

DIRBIT = 64
CC     = gcc
LUAEXE = lua
CFLAGS = -O2 -Wall -Wno-unused-function \
         -I$(INC_FAR) -I$(INC_WIN) -I$(INC_LUA) \
         -m$(DIRBIT) -fPIC $(MYCFLAGS)

LDFLAGS = -shared -m$(DIRBIT) -fPIC $(MYLDFLAGS)

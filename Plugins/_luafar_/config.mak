# User-configurable settings
# ---------------------------

FARSOURCE  = $(HOME)/far2l
FARINSTALL = $(HOME)/far2l/_build/install

# Settings below do not usually require editing
# ----------------------------------------------

INC_FAR = $(FARSOURCE)/far2l/far2sdk
INC_WIN = $(FARSOURCE)/WinPort
INC_LUA = /usr/include/lua5.1

PATH_LUAFAR = $(FARINSTALL)/Plugins/_luafar_
LUA_SHARE   = $(PATH_LUAFAR)/lua_share
LUAFARDLL   = luafar2l.so

DIRBIT = 64
CC     = gcc
LUAEXE = lua
CFLAGS = -O2 -Wall -Wno-unused-function \
         -I$(INC_FAR) -I$(INC_WIN) -I$(INC_LUA) -I$(PATH_LUAFAR)/src \
         -m$(DIRBIT) -fPIC $(MYCFLAGS)

LDFLAGS = -shared -m$(DIRBIT) -s -fPIC $(MYLDFLAGS)

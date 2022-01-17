FARSOURCE  = $(HOME)/far2l
FARINSTALL = $(HOME)/far2l/_build/install

INC_FAR    = $(FARSOURCE)/far2l/Include
INC_WIN    = $(FARSOURCE)/WinPort
INC_LUA    = $(PATH_LUAFAR)/include/lua

PATH_LUAFAR    = $(FARINSTALL)/Plugins/_luafar_
PATH_LUAFARSRC = $(PATH_LUAFAR)/src
LUA_SHARE      = $(PATH_LUAFAR)/lua_share
LUAFARDLL      = luafar2l.so 
PATH_INSTALL   = /usr/lib/x86_64-linux-gnu

DIRBIT     = 64
CC         = gcc
LUAEXE     = lua
CFLAGS     = -O2 -Wall -Wno-unused-function \
             -I$(INC_FAR) -I$(INC_WIN) -I$(INC_LUA) \
             -m$(DIRBIT) -fPIC $(MYCFLAGS)

LDFLAGS    = -shared -m$(DIRBIT) -s -fPIC $(MYLDFLAGS)

ifdef FAR_EXPORTS
    EXPORTS = $(addprefix -DEXPORT_,$(FAR_EXPORTS))
endif

ifdef MINFARVERSION
    FARVERSION = -DMINFARVERSION=MAKEFARVERSION($(MINFARVERSION))
endif

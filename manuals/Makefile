# Example:
#   make lf SHOW=1 ARTICLE_ID=10

APPDIR= C:\Program Files (x86)\HTML Help Workshop
PATH := $(APPDIR);$(PATH)
LUA_INIT  =
LUA_PATH  = ./?.lua;./?/init.lua
LUA_CPATH = ./?.dll

# LuaFAR manual
lf: FILE_SRC = src\luafar2l_manual.tsi
lf: DIR_OUT = out\luafar_unicode
lf: TP2HH = tp2hh_old.lua

# LuaMacro manual
lm: FILE_SRC = src\macroapi_manual_linux.tsi
lm: DIR_OUT = out\luamacro
lm: TP2HH = tp2hh_new.lua

# LF4Ed manual
l4: FILE_SRC = src\lf4ed_manual.tsi
l4: DIR_OUT = out\lf4ed
l4: TP2HH = tp2hh_old.lua

name = $(basename $(notdir $(FILE_SRC)))
CHM = $(DIR_OUT)\$(name).chm
HHP = $(DIR_OUT)\$(name).hhp

ifdef ARTICLE_ID
  SUFFIX = ::$(ARTICLE_ID).html
endif

lf lm l4: $(CHM)

$(CHM): $(HHP)
	-hhc.exe $(HHP)
ifdef SHOW
	$(ComSpec) /C start hh.exe $(CHM)$(SUFFIX)
endif

$(HHP): $(FILE_SRC)
	@if not exist $(DIR_OUT) mkdir $(DIR_OUT)
	set LUA_PATH=$(LUA_PATH) && set LUA_CPATH=$(LUA_CPATH) && lua $(TP2HH) $(FILE_SRC) templates\api.tem $(DIR_OUT)

clean:
	@if exist out rmdir /s /q out

.PHONY: lf lm l4 clean

# Example:
#   make lf SHOW=1 ARTICLE_ID=10

APPDIR= C:\Program Files (x86)\HTML Help Workshop
PATH := $(APPDIR);$(PATH)

# LuaFAR manual
lf: FILE_SRC = src\luafar2l_manual.tsi
lf: DIR_OUT = out\luafar_unicode

# LuaMacro manual
lm: FILE_SRC = src\macroapi_manual_linux.tsi
lm: DIR_OUT = out\luamacro

# LF4Ed manual
l4: FILE_SRC = src\lf4ed_manual.tsi
l4: DIR_OUT = out\lf4ed

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
	set LUA_INIT= && lua tp2hh.lua $(FILE_SRC) tem=templates\api.tem lib=tsi out=$(DIR_OUT)

clean:
	@if exist out rmdir /s /q out

.PHONY: lf lm l4 clean

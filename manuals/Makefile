DIR_BASE   = ..
DIR_LUAFAR = $(DIR_BASE)\luafar\doc
DIR_LF4ED  = $(DIR_BASE)\_lf4ed_\doc

APPDIR= C:\Program Files (x86)\HTML Help Workshop
PATH := $(APPDIR);$(PATH)

.PHONY: lfar lf4

lfar: SRC = $(DIR_LUAFAR)\luafar2l_manual.tsi
lfar: OUT = luafar_unicode
lfar: INSTALL = $(DIR_LUAFAR)

lf4:  SRC = $(DIR_LF4ED)\lf4ed_manual.tsi
lf4:  OUT = lf4ed
lf4:  INSTALL = $(DIR_LF4ED)

NAME = $(OUT)\$(basename $(notdir $(SRC)))
ARTICLE_ID =

CHM = $(NAME).chm
HHP = $(NAME).hhp

ifdef ARTICLE_ID
  SUFFIX = ::/$(ARTICLE_ID).html
endif

lfar lf4: $(CHM) display

$(CHM): $(HHP)
	-hhc.exe $(HHP)
	copy /y $(CHM) $(INSTALL)

$(HHP): $(SRC)
	set LUA_INIT= && lua tp2hh.lua $(SRC) tem=templates\api.tem lib=tsi out=$(OUT)

display: $(CHM)
	$(ComSpec) /C start hh.exe $(CHM)$(SUFFIX)

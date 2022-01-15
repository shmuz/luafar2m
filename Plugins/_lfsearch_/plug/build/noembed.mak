# noembed.mak

FAR_EXPORTS = OPENPLUGINW
include ../../../_luafar_/config.mak

ifeq ($(DIRBIT),64)
  TARGET = replace-x64.far-plug-wide
else
  TARGET = replace.far-plug-wide
endif

include ../../../_luafar_/src/luaplug.mak

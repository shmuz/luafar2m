# noembed.mak

FAR_EXPORTS = OPENPLUGINW
include ../../../_luafar_/config.mak

ifeq ($(DIRBIT),64)
  TARGET = lfsearch-x64.far-plug-wide
else
  TARGET = lfsearch.far-plug-wide
endif

include ../../../_luafar_/src/luaplug.mak

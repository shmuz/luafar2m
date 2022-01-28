# noembed.mak

FAR_EXPORTS = OPENPLUGIN
include ../../config.mak

ifeq ($(DIRBIT),64)
  TARGET = ../plug/lfsearch-x64.far-plug-wide
else
  TARGET = ../plug/lfsearch.far-plug-wide
endif

include ../../src/luaplug.mak

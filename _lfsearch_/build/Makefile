PLUGNAME = lfsearch
CONFIG   = lfsearch.cfg
LANG_GEN = lfs_lang.lua
C_SOURCE = ../plug/reader.c
MYCFLAGS = -I$(FARSOURCE)/luafar/src
FUNC_OPENLIBS = luaopen_reader
SYS_ID   = 0x8E11EA75
SETPACKAGEPATH = 1

FAR_EXPORTS =           \
  CLOSEPLUGIN           \
  CONFIGURE             \
  EXITFAR               \
  GETFINDDATA           \
  GETOPENPLUGININFO     \
  OPENFILEPLUGIN        \
  OPENPLUGIN            \
  PROCESSEDITOREVENT    \
  PROCESSEVENT          \
  PROCESSKEY            \
  PUTFILES              \
  SETDIRECTORY          \
  SETFINDLIST

include ../../plugin.mak

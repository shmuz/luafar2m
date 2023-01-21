PLUGNAME = polygon
CONFIG   = polygon.cfg
LANG_GEN = polygon_lang.lua
C_SOURCE = ../plug/polygon.c
MYCFLAGS = -I$(FARSOURCE)/luafar/src
MYLDFLAGS = -lsqlite3
FUNC_OPENLIBS = luaopen_polygon
SYS_ID = 0xD4BC5EA7
SETPACKAGEPATH = 1

SRC_PLUG_DIRS = modules

# Do not include COMPARE - it is in "polygon.c".
FAR_EXPORTS = \
  CLOSEPLUGIN        \
  CONFIGURE          \
  DELETEFILES        \
  FREEFINDDATA       \
  GETFINDDATA        \
  GETOPENPLUGININFO  \
  OPENFILEPLUGIN     \
  OPENPLUGIN         \
  PROCESSEVENT       \
  PROCESSKEY         \
  SETDIRECTORY

include ../../plugin.mak

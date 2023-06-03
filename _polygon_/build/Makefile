PLUGNAME = polygon
CONFIG   = polygon.cfg
LANG_GEN = polygon_lang.lua
C_SOURCE = ../plug/polygon.c
MYCFLAGS = -I$(FARSOURCE)/luafar/src
MYLDFLAGS = -lsqlite3
FUNC_OPENLIBS = luaopen_polygon
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

# Global Info
SYS_ID             = 0xD4BC5EA7
PLUG_MINFARVERSION = "MAKEFARVERSION(2,4)"
PLUG_VERSION       = "MAKEPLUGVERSION(1,8,2,0)"
PLUG_TITLE         = \"Polygon\"
PLUG_DESCRIPTION   = \"Plugin for viewing and editing SQLite3 database files\"
PLUG_AUTHOR        = \"Artem Senichev, Shmuel Zeigerman\"

include ../../plugin.mak

luaplug1.o luaplug2.o : ../plug/lsqlite3.c

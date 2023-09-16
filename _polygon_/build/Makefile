PLUGNAME = polygon
LANG_TEMPL = polygon_lang.templ
C_SOURCE = ../plug/polygon.c
MYCFLAGS = -I$(FARSOURCE)/luafar/src
MYLDFLAGS = -lsqlite3
FUNC_OPENLIBS = luaopen_polygon

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
PLUG_VERSION       = "1,8,2,0"
PLUG_TITLE         = \"Polygon\"
PLUG_DESCRIPTION   = \"Plugin for viewing and editing SQLite3 database files\"
PLUG_AUTHOR        = \"Artem Senichev, Shmuel Zeigerman\"

# Embedding data
BOOTSCRIPT = ../plug/polygon.lua
SCRIPTS = -
MODULES = \
  ../plug*modules/editor.lua             \
  ../plug*modules/exporter.lua           \
  ../plug*modules/panel.lua              \
  ../plug*modules/progress.lua           \
  ../plug*modules/config.lua             \
  ../plug*modules/sqlite.lua             \
  ../plug*modules/string_rc.lua          \
  ../plug*modules/utils.lua              \
  $(LUA_SHARE)*far2/plugdebug.lua        \
  $(LUA_SHARE)*far2/settings.lua         \
  $(LUA_SHARE)*far2/simpledialog.lua

include ../../plugin.mak

luaplug1.o luaplug2.o : ../plug/lsqlite3.c

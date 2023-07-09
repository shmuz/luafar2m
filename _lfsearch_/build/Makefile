PLUGNAME = lfsearch
LANG_TEMPL = lfs_lang.templ
C_SOURCE = ../plug/reader.c
MYCFLAGS = -I$(FARSOURCE)/luafar/src
FUNC_OPENLIBS = luaopen_reader
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

# Global Info
SYS_ID             = 0x8E11EA75
PLUG_MINFARVERSION = "MAKEFARVERSION(2,4)"
PLUG_VERSION       = "3,45,5,0"
PLUG_TITLE         = \"LuaFAR Search\"
PLUG_DESCRIPTION   = \"Plugin for search and replace\"
PLUG_AUTHOR        = \"Shmuel Zeigerman\"

# Embedding data
BOOTSCRIPT = ../plug/lfsearch.lua
SCRIPTS = -
MODULES = \
  ../plug*lfs_common.lua                 \
  ../plug*lfs_editengine.lua             \
  ../plug*lfs_editmain.lua               \
  ../plug*lfs_editors.lua                \
  ../plug*lfs_message.lua                \
  ../plug*lfs_mreplace.lua               \
  ../plug*lfs_panels.lua                 \
  ../plug*lfs_rename.lua                 \
  ../plug*lfs_replib.lua                 \
  $(LUA_SHARE)*cqueue.lua                \
  $(LUA_SHARE)*far2/custommenu.lua       \
  $(LUA_SHARE)*far2/message.lua          \
  $(LUA_SHARE)*far2/settings.lua         \
  $(LUA_SHARE)*far2/simpledialog.lua     \
  $(LUA_SHARE)*far2/tmppanel.lua         \
  $(LUA_SHARE)*far2/utils.lua            \
  $(LUA_SHARE)*far2/xlat.lua

include ../../plugin.mak

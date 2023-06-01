PLUGNAME = lfsearch
CONFIG   = lfsearch.cfg
LANG_GEN = lfs_lang.lua
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
PLUG_MINFARVERSION = 0x00020004
PLUG_VERSION       = 0x032D0005
PLUG_TITLE         = \"LuaFAR Search\"
PLUG_DESCRIPTION   = \"Plugin for search and replace\"
PLUG_AUTHOR        = \"Shmuel Zeigerman\"

include ../../plugin.mak

PLUGNAME = lftmp
LANG_TEMPL = tmpp_lang.templ

FAR_EXPORTS = \
  CLOSEPLUGIN  CONFIGURE  EXITFAR  GETFINDDATA  GETOPENPLUGININFO \
  OPENFILEPLUGIN  OPENPLUGIN  PROCESSEVENT  PROCESSKEY  PUTFILES  \
  SETDIRECTORY  SETFINDLIST

# Global Info
SYS_ID             = 0xE2500D1C
PLUG_MINFARVERSION = "MAKEFARVERSION(2,4)"
PLUG_VERSION       = "3,1,2,0"
PLUG_TITLE         = \"LuaFAR Temp. Panel\"
PLUG_DESCRIPTION   = \"A Lua clone of TmpPanel plugin\"
PLUG_AUTHOR        = \"Far Group, Shmuel Zeigerman\"

# Embedding data
BOOTSCRIPT = ../plug/lftmp.lua
SCRIPTS = -
MODULES = \
  ../plug*tmpp_message.lua               \
  $(LUA_SHARE)*far2/settings.lua         \
  $(LUA_SHARE)*far2/simpledialog.lua     \
  $(LUA_SHARE)*far2/tmppanel.lua         \
  $(LUA_SHARE)*far2/utils.lua

include ../../plugin.mak

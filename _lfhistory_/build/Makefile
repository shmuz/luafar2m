PLUGNAME = lfhistory
CONFIG   = lfhistory.cfg
LANG_TEMPL = lfh_lang.templ
SETPACKAGEPATH = 1

FAR_EXPORTS = CONFIGURE  OPENPLUGIN

# Global Info
SYS_ID             = 0xA745761D
PLUG_MINFARVERSION = "MAKEFARVERSION(2,4)"
PLUG_VERSION       = "3,11,1,0"
PLUG_TITLE         = \"LuaFAR History\"
PLUG_DESCRIPTION   = \"History of commands, files and folders\"
PLUG_AUTHOR        = \"Shmuel Zeigerman\"

# Embedding data
BOOTSCRIPT = ../plug/lfhistory.lua
SCRIPTS = -
MODULES = \
  ../plug*lfh_config.lua                 \
  ../plug*lfh_message.lua                \
  $(LUA_SHARE)*inifile.lua               \
  $(LUA_SHARE)*far2/custommenu.lua       \
  $(LUA_SHARE)*far2/settings.lua         \
  $(LUA_SHARE)*far2/simpledialog.lua     \
  $(LUA_SHARE)*far2/utils.lua            \
  $(LUA_SHARE)*far2/xlat.lua

include ../../plugin.mak

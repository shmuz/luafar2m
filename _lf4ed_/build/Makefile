PLUGNAME = lf4ed
CONFIG   = lf4ed.cfg
LANG_TEMPL = lf4ed_lang.templ
SETPACKAGEPATH = 1

SRC_PLUG_DIRS = scripts

FAR_EXPORTS = \
  CONFIGURE  EXITFAR  MAYEXITFAR  OPENPLUGIN  PROCESSEDITOREVENT \
  PROCESSEDITORINPUT  PROCESSVIEWEREVENT  PROCESSDIALOGEVENT

# Global Info
SYS_ID             = 0x6F332978
PLUG_MINFARVERSION = "MAKEFARVERSION(2,4)"
PLUG_VERSION       = "3,9,3,0"
PLUG_TITLE         = \"LuaFAR for Editor\"
PLUG_DESCRIPTION   = \"A host for scripts and script packets\"
PLUG_AUTHOR        = \"Shmuel Zeigerman\"

# Embedding data
BOOTSCRIPT = ../plug/lf4ed.lua
SCRIPTS = \
  ../plug/config.lua                     \
  ../plug/expression.lua                 \
  ../plug/wrap.lua
MODULES = \
  ../plug*lf4ed_message.lua              \
  ../plug*sortdialog.lua                 \
  ../plug*sortlines.lua                  \
  $(LUA_SHARE)*far2/makelang.lua         \
  $(LUA_SHARE)*far2/settings.lua         \
  $(LUA_SHARE)*far2/simpledialog.lua     \
  $(LUA_SHARE)*far2/utils.lua

include ../../plugin.mak

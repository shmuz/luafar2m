PLUGNAME = hlfviewer
LANG_TEMPL = hv_lang.templ
SETPACKAGEPATH = 1

SRC_PLUG_SHARE = *.lua *.hlf *.lng

FAR_EXPORTS = OPENPLUGIN PROCESSEDITORINPUT CONFIGURE

# Global Info
SYS_ID             = 0x1AF0754D
PLUG_MINFARVERSION = "MAKEFARVERSION(2,4)"
PLUG_VERSION       = "3,0,0,49"
PLUG_TITLE         = \"HlfViewer\"
PLUG_DESCRIPTION   = \"Hlf-file Viewer for Far Manager\"
PLUG_AUTHOR        = \"Far Group, Shmuel Zeigerman\"

# Embedding data
BOOTSCRIPT = ../plug/hlfviewer.lua
SCRIPTS = -
MODULES = \
  ../plug*hv_message.lua                 \
  $(LUA_SHARE)*far2/settings.lua         \
  $(LUA_SHARE)*far2/simpledialog.lua

include ../../plugin.mak

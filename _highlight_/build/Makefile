PLUGNAME = highlight

SRC_PLUG_DIRS = syntaxes
SRC_PLUG_SHARE = *.lua *.hlf

FAR_EXPORTS = OPENPLUGIN PROCESSEDITOREVENT PROCESSEDITORINPUT

# Global Info
SYS_ID             = 0xF6138DC9
PLUG_MINFARVERSION = "MAKEFARVERSION(2,4)"
PLUG_VERSION       = "0,5,1,0"
PLUG_TITLE         = \"Highlight\"
PLUG_DESCRIPTION   = \"Syntax highlighter for editor\"
PLUG_AUTHOR        = \"Shmuel Zeigerman\"

# Embedding data
BOOTSCRIPT = ../plug/highlight.lua
SCRIPTS = -
MODULES = \
  $(LUA_SHARE)*far2/settings.lua         \
  $(LUA_SHARE)*far2/simpledialog.lua

include ../../plugin.mak

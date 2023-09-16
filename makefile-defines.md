# Definitions for customizing make files of LuaFAR plugins

# Table of Contents
1. [PLUGNAME](#PLUGNAME)
1. [SYS_ID](#SYS_ID)
1. [FAR_EXPORTS](#FAR_EXPORTS)
1. [LANG_TEMPL](#LANG_TEMPL)
1. [C_SOURCE](#C_SOURCE)
1. [FUNC_OPENLIBS](#FUNC_OPENLIBS)
1. [MYCFLAGS](#MYCFLAGS)
1. [MYLDFLAGS](#MYLDFLAGS)
1. [NOSETPACKAGEPATH](#NOSETPACKAGEPATH)
1. [SRC_PLUG_DIRS](#SRC_PLUG_DIRS)
1. [SRC_PLUG_LIB](#SRC_PLUG_LIB)
1. [SRC_PLUG_SHARE](#SRC_PLUG_SHARE)

## PLUGNAME
- The base name of the plugin
- Used for naming of the plugins's DLL and installation directories
- Mandatory
- Example: `PLUGNAME = polygon`

## SYS_ID
- A 32-bit unsigned number that uniquely identifies the given plugin
- Mandatory
- Example: `SYS_ID = 0xD4BC5EA7`

## FAR_EXPORTS
- A list of functions that should be exported by the plugin
  (in uppercase, whitespace-separated)
- The functions *SetStartupInfoW*, *GetGlobalInfoW*, *GetPluginInfoW* and *ProcessSynchroEventW*
  are always exported, so there's no need to include them in the list.
- Example: `FAR_EXPORTS = OPENPLUGIN EXITFAR`

## LANG_TEMPL
- Name of a "template" file containing strings for all the languages
  supported by the plugin
- Not required if the plugin does not have `*.templ` files
- Example: `LANG_TEMPL = polygon_lang.templ`

## C_SOURCE
- This is the main plugin's C-file
- Optional, defaults to `$(FARSOURCE)/luafar/src/luaplug.c`
- Example: `C_SOURCE = ../plug/polygon.c`

## FUNC_OPENLIBS
- Name of a function to call on plugin's initialization
- It is a C-function of `lua_CFunction` type
- Intended for loading additional libraries
- Optional
- Example: `FUNC_OPENLIBS = luaopen_polygon`

## MYCFLAGS
- Additional C-flags or other parameters to be included in a compilation command
- Optional
- Example: `MYCFLAGS = -I$(FARSOURCE)/luafar/src`

## MYLDFLAGS
- Additional flags or other parameters to be included in a linking command
- Optional
- Example: `MYLDFLAGS = -lsqlite3`

## NOSETPACKAGEPATH
- If defined then `-DNOSETPACKAGEPATH` is added to CFLAGS which prevents
  the plugin's path and the "lua_share" path from being prepended to `package.path`

## SRC_PLUG_DIRS
- A list of directories (relative to plugin's path) to be copied during installation
- Not needed if all plugin's files are in a single directory
- Example: `SRC_PLUG_DIRS = modules`

## SRC_PLUG_LIB
- A list of DLL's to be copied during installation
- Not needed if the plugin consists of a single DLL
- Example: `SRC_PLUG_LIB = $(PLUGNAME).far-plug-wide reader.so`

## SRC_PLUG_SHARE
- A list of non-DLL files to be copied during installation
- Optional, defaults to `*.lua *.lng *.hlf`
- Example: `SRC_PLUG_SHARE = *.lua *.lng`

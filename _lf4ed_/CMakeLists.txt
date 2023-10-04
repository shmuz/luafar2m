project(lf4ed)

set(SOURCES
  ${FARSOURCE}/luafar/src/luaplug.c
)

add_library (${PROJECT_NAME} MODULE ${SOURCES})
set_property(TARGET ${PROJECT_NAME} PROPERTY C_STANDARD 11)

set(EXPNAMES
  CONFIGURE  EXITFAR  MAYEXITFAR  OPENPLUGIN  PROCESSEDITOREVENT
  PROCESSEDITORINPUT  PROCESSVIEWEREVENT  PROCESSDIALOGEVENT
)

set(EXPORTS "")
foreach(f ${EXPNAMES})
  list(APPEND EXPORTS "-DEXPORT_${f}")
endforeach()

target_compile_definitions(${PROJECT_NAME}
  PRIVATE ${EXPORTS}
  PRIVATE "-DSYS_ID=0x6F332978"
  PRIVATE "-DPLUG_MINFARVERSION=MAKEFARVERSION(2,4)"
  PRIVATE "-DPLUG_VERSION=3,9,3,0"
  PRIVATE "-DPLUG_TITLE=\"LuaFAR for Editor\""
  PRIVATE "-DPLUG_DESCRIPTION=\"A host for scripts and script packets\""
  PRIVATE "-DPLUG_AUTHOR=\"Shmuel Zeigerman\""
)

target_include_directories(${PROJECT_NAME} PRIVATE ${FARSOURCE}/far/far2sdk)

set(INSTALL_DIR "${INSTALL_DIR}/Plugins/luafar/${PROJECT_NAME}")

set_target_properties(${PROJECT_NAME}
  PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${INSTALL_DIR}/plug"
    PREFIX ""
    SUFFIX ".far-plug-wide")

set(MY_LIST
  config.lua
  expression.lua
  lf4ed.lua
  sortdialog.lua
  sortlines.lua
  wrap.lua
  _usermenu.lua
  lf4ed_eng.hlf
  lf4ed_rus.hlf
)

foreach(elem ${MY_LIST})
  configure_file("plug/${elem}" "${INSTALL_DIR}/plug/${elem}" COPYONLY)
endforeach()

add_custom_target(langfiles ALL
  minilua ${LUA_SHARE}/makelang.lua ${CMAKE_CURRENT_SOURCE_DIR}/plug/lf4ed_lang.templ ${INSTALL_DIR}/plug
)

add_custom_target(scripts ALL
  COMMAND cp -rf "${CMAKE_CURRENT_SOURCE_DIR}/plug/scripts" "${INSTALL_DIR}/plug/"
)

project(lftmp)

set(SOURCES
  ${FARSOURCE}/luafar/src/luaplug.c
)

add_library (${PROJECT_NAME} MODULE ${SOURCES})
set_property(TARGET ${PROJECT_NAME} PROPERTY C_STANDARD 11)

set(EXPNAMES
  CLOSEPLUGIN  CONFIGURE  EXITFAR  GETFINDDATA  GETOPENPLUGININFO
  OPENFILEPLUGIN  OPENPLUGIN  PROCESSEVENT  PROCESSKEY  PUTFILES
  SETDIRECTORY  SETFINDLIST
)

set(EXPORTS "")
foreach(f ${EXPNAMES})
  list(APPEND EXPORTS "-DEXPORT_${f}")
endforeach()

target_compile_definitions(${PROJECT_NAME}
  PRIVATE ${EXPORTS}
  PRIVATE "-DSYS_ID=0xE2500D1C"
  PRIVATE "-DPLUG_MINFARVERSION=MAKEFARVERSION(2,4)"
  PRIVATE "-DPLUG_VERSION=3,1,2,0"
  PRIVATE "-DPLUG_TITLE=\"LuaFAR Temp. Panel\""
  PRIVATE "-DPLUG_DESCRIPTION=\"A Lua clone of TmpPanel plugin\""
  PRIVATE "-DPLUG_AUTHOR=\"Far Group, Shmuel Zeigerman\""
)

target_include_directories(${PROJECT_NAME} PRIVATE
  ${FARSOURCE}/far/far2sdk)

set(INSTALL_DIR "${INSTALL_DIR}/${PROJECT_NAME}")

set_target_properties(${PROJECT_NAME}
  PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${INSTALL_DIR}/plug"
    PREFIX ""
    SUFFIX ".far-plug-wide")

set(MY_LIST
  lftmp.lua
  LuaTmpEng.hlf
  LuaTmpRus.hlf
)

foreach(elem ${MY_LIST})
  configure_file("plug/${elem}" "${INSTALL_DIR}/plug/${elem}" COPYONLY)
endforeach()

add_custom_target(${PROJECT_NAME}_lang ALL
  minilua ${LUA_SHARE}/makelang.lua ${CMAKE_CURRENT_SOURCE_DIR}/plug/tmpp_lang.templ ${INSTALL_DIR}/plug
)
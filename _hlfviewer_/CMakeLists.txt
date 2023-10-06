project(hlfviewer)

set(SOURCES
  ${FARSOURCE}/luafar/src/luaplug.c
)

add_library (${PROJECT_NAME} MODULE ${SOURCES})
set_property(TARGET ${PROJECT_NAME} PROPERTY C_STANDARD 11)

set(EXPNAMES
  OPENPLUGIN PROCESSEDITORINPUT CONFIGURE
)

set(EXPORTS "")
foreach(f ${EXPNAMES})
  list(APPEND EXPORTS "-DEXPORT_${f}")
endforeach()

target_compile_definitions(${PROJECT_NAME}
  PRIVATE ${EXPORTS}
  PRIVATE "-DSYS_ID=0x1AF0754D"
  PRIVATE "-DPLUG_MINFARVERSION=MAKEFARVERSION(2,4)"
  PRIVATE "-DPLUG_VERSION=3,0,0,49"
  PRIVATE "-DPLUG_TITLE=\"HlfViewer\""
  PRIVATE "-DPLUG_DESCRIPTION=\"Hlf-file Viewer for Far Manager\""
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
  hlfviewer.lua
  HlfViewerUkr.hlf
  HlfViewerRus.hlf
  HlfViewerPol.hlf
  HlfViewerEng.hlf
  LICENSE
)

foreach(elem ${MY_LIST})
  configure_file("plug/${elem}" "${INSTALL_DIR}/plug/${elem}" COPYONLY)
endforeach()

add_custom_target(${PROJECT_NAME}_lang ALL
  minilua ${LUA_SHARE}/makelang.lua ${CMAKE_CURRENT_SOURCE_DIR}/plug/hv_lang.templ ${INSTALL_DIR}/plug
)

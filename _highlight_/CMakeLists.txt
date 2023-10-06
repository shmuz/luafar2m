project(highlight)

set(SOURCES
  ${FARSOURCE}/luafar/src/luaplug.c
)

add_library (${PROJECT_NAME} MODULE ${SOURCES})
set_property(TARGET ${PROJECT_NAME} PROPERTY C_STANDARD 11)

set(EXPNAMES
  OPENPLUGIN PROCESSEDITOREVENT PROCESSEDITORINPUT
)

set(EXPORTS "")
foreach(f ${EXPNAMES})
  list(APPEND EXPORTS "-DEXPORT_${f}")
endforeach()

target_compile_definitions(${PROJECT_NAME}
  PRIVATE ${EXPORTS}
  PRIVATE "-DSYS_ID=0xF6138DC9"
  PRIVATE "-DPLUG_MINFARVERSION=MAKEFARVERSION(2,4)"
  PRIVATE "-DPLUG_VERSION=0,5,1,0"
  PRIVATE "-DPLUG_TITLE=\"Highlight\""
  PRIVATE "-DPLUG_DESCRIPTION=\"Syntax highlighter for editor\""
  PRIVATE "-DPLUG_AUTHOR=\"Shmuel Zeigerman\""
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
  highlight.lua
  highlight_eng.hlf
)

foreach(elem ${MY_LIST})
  configure_file("plug/${elem}" "${INSTALL_DIR}/plug/${elem}" COPYONLY)
endforeach()

add_custom_target(${PROJECT_NAME}_files ALL
  COMMAND cp -rf "${CMAKE_CURRENT_SOURCE_DIR}/plug/syntaxes" "${INSTALL_DIR}/plug/"
)

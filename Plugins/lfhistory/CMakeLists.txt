project(lfhistory)

set(SOURCES
  ${FARSOURCE}/luafar/src/luaplug.c
  plug/GlobalInfo.c
)

add_library (${PROJECT_NAME} MODULE ${SOURCES})
set_property(TARGET ${PROJECT_NAME} PROPERTY C_STANDARD 11)

set(EXPNAMES
  CONFIGURE OPENPLUGIN
)

set(EXPORTS "")
foreach(f ${EXPNAMES})
  list(APPEND EXPORTS "-DEXPORT_${f}")
endforeach()

target_compile_definitions(${PROJECT_NAME}
  PRIVATE ${EXPORTS}
  PRIVATE "-DPLUG_MINFARVERSION=MAKEFARVERSION(2,4)"
)

target_include_directories(${PROJECT_NAME} PRIVATE ${FARSOURCE}/far/far2sdk)

set(INSTALL_DIR "${INSTALL_DIR}/${PROJECT_NAME}")

set_target_properties(${PROJECT_NAME}
  PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${INSTALL_DIR}/plug"
    PREFIX ""
    SUFFIX ".far-plug-wide")

set(MY_LIST
  lfhistory.lua
  lfh_config.lua
  lfh_eng.hlf
  lfh_rus.hlf
)

foreach(elem ${MY_LIST})
  configure_file("plug/${elem}" "${INSTALL_DIR}/plug/${elem}" COPYONLY)
endforeach()

add_custom_target(${PROJECT_NAME}_lang ALL
  minilua ${LUA_SHARE}/makelang.lua ${CMAKE_CURRENT_SOURCE_DIR}/plug/lfh_lang.templ ${INSTALL_DIR}/plug
)

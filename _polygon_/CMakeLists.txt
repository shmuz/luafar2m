project(polygon)

set(SOURCES
  plug/polygon.c
)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DFUNC_OPENLIBS=luaopen_polygon")

add_library (${PROJECT_NAME} MODULE ${SOURCES})
set_property(TARGET ${PROJECT_NAME} PROPERTY C_STANDARD 11)

set(EXPNAMES
  CLOSEPLUGIN  CONFIGURE  DELETEFILES  FREEFINDDATA  GETFINDDATA
  GETOPENPLUGININFO  OPENFILEPLUGIN  OPENPLUGIN  PROCESSEVENT
  PROCESSKEY  SETDIRECTORY
)

set(EXPORTS "")
foreach(f ${EXPNAMES})
  list(APPEND EXPORTS "-DEXPORT_${f}")
endforeach()

target_compile_definitions(${PROJECT_NAME}
  PRIVATE ${EXPORTS}
  PRIVATE "-DSYS_ID=0xD4BC5EA7"
  PRIVATE "-DPLUG_MINFARVERSION=MAKEFARVERSION(2,4)"
  PRIVATE "-DPLUG_VERSION=1,8,2,0"
  PRIVATE "-DPLUG_TITLE=\"Polygon\""
  PRIVATE "-DPLUG_DESCRIPTION=\"Plugin for viewing and editing SQLite3 database files\""
  PRIVATE "-DPLUG_AUTHOR=\"Artem Senichev, Shmuel Zeigerman\""
)

target_include_directories(${PROJECT_NAME} PRIVATE
  ${FARSOURCE}/far/far2sdk
  ${FARSOURCE}/luafar/src)

set(INSTALL_DIR "${INSTALL_DIR}/${PROJECT_NAME}")

set_target_properties(${PROJECT_NAME}
  PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${INSTALL_DIR}/plug"
    PREFIX ""
    SUFFIX ".far-plug-wide")

target_link_libraries(${PROJECT_NAME} PRIVATE sqlite3)

set(MY_LIST
  polygon.lua
  modules/panel.lua
  modules/exporter.lua
  modules/progress.lua
  modules/editor.lua
  modules/sqlite.lua
  modules/utils.lua
  modules/config.lua
  polygon_eng.hlf
  polygon_rus.hlf
  polygon.example.ini
)

foreach(elem ${MY_LIST})
  configure_file("plug/${elem}" "${INSTALL_DIR}/plug/${elem}" COPYONLY)
endforeach()

add_custom_target(${PROJECT_NAME}_lang ALL
  minilua ${LUA_SHARE}/makelang.lua ${CMAKE_CURRENT_SOURCE_DIR}/plug/polygon_lang.templ ${INSTALL_DIR}/plug
)

# add_custom_target(${PROJECT_NAME}_files ALL
#   COMMAND cp -rf "${CMAKE_CURRENT_SOURCE_DIR}/plug/scripts" "${INSTALL_DIR}/plug/"
#   COMMAND cp -rf "${CMAKE_CURRENT_SOURCE_DIR}/plug/doc" "${INSTALL_DIR}/plug/"
# )

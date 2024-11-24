project(polygon)

set(SOURCES
  src/GlobalInfo.c
  src/polygon.c
  ../_common/lsqlite3.c
  ${FARSOURCE}/luafar/src/luaplug.c
)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DFUNC_OPENLIBS=luaopen_polygon")

add_library (${PROJECT_NAME} MODULE ${SOURCES})
set_property(TARGET ${PROJECT_NAME} PROPERTY C_STANDARD 11)

target_include_directories(polygon PRIVATE ${SQLITE3_INCLUDE_DIRS})
target_link_libraries(polygon ${SQLITE3_LIBRARIES})

set(EXPNAMES
  ANALYSE CLOSEPLUGIN  CONFIGURE  DELETEFILES  GETFINDDATA
  GETOPENPLUGININFO  OPENPLUGIN  PROCESSEVENT  PROCESSKEY
  SETDIRECTORY
)

set(EXPORTS "")
foreach(f ${EXPNAMES})
  list(APPEND EXPORTS "-DEXPORT_${f}")
endforeach()

target_compile_definitions(${PROJECT_NAME}
  PRIVATE ${EXPORTS}
)

target_include_directories(${PROJECT_NAME} PRIVATE
  ${FARSOURCE}/far/far2sdk
  ${FARSOURCE}/luafar/src)

if(${CMAKE_SYSTEM_NAME} MATCHES "Android")
  target_link_libraries(${PROJECT_NAME} ${CMAKE_SOURCE_DIR}/luafar.so)
endif()

set(INSTALL_DIR "${INSTALL_DIR}/${PROJECT_NAME}")

set_target_properties(${PROJECT_NAME}
  PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${INSTALL_DIR}/plug"
    PREFIX ""
    SUFFIX ".far-plug-wide")

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
  configure_file("src/${elem}" "${INSTALL_DIR}/plug/${elem}" COPYONLY)
endforeach()

add_custom_target(${PROJECT_NAME}_lang ALL
  minilua ${LUA_SHARE}/makelang.lua ${CMAKE_CURRENT_SOURCE_DIR}/src/polygon_lang.templ ${INSTALL_DIR}/plug
)

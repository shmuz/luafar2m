project(lfsearch)

set(SOURCES
  src/GlobalInfo.c
  src/reader.c
  ${FARSOURCE}/luafar/src/luaplug.c
)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DFUNC_OPENLIBS=luaopen_reader")

add_library (${PROJECT_NAME} MODULE ${SOURCES})
set_property(TARGET ${PROJECT_NAME} PROPERTY C_STANDARD 11)

set(EXPNAMES
  CLOSEPLUGIN  CONFIGURE  EXITFAR  GETFINDDATA  GETOPENPLUGININFO  OPENFILEPLUGIN
  OPENPLUGIN  PROCESSEDITOREVENT  PROCESSEVENT  PROCESSKEY  PUTFILES  SETDIRECTORY
  SETFINDLIST
)

set(EXPORTS "")
foreach(f ${EXPNAMES})
  list(APPEND EXPORTS "-DEXPORT_${f}")
endforeach()

target_compile_definitions(${PROJECT_NAME}
  PRIVATE ${EXPORTS}
)

target_include_directories(${PROJECT_NAME} PRIVATE
  ${FARSOURCE}/far/far2sdk)

if(${CMAKE_SYSTEM_NAME} MATCHES "Android")
  target_link_libraries(${PROJECT_NAME} lua5.1)
  target_link_libraries(${PROJECT_NAME} ${CMAKE_SOURCE_DIR}/luafar.so)
endif()

set(INSTALL_DIR "${INSTALL_DIR}/${PROJECT_NAME}")

set_target_properties(${PROJECT_NAME}
  PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${INSTALL_DIR}/plug"
    PREFIX ""
    SUFFIX ".far-plug-wide")

set(MY_LIST
  lfsearch.lua
  lfs_common.lua
  lfs_editengine.lua
  lfs_editmain.lua
  lfs_editors.lua
  lfs_mreplace.lua
  lfs_panels.lua
  lfs_rename.lua
  lfs_replib.lua
  _usermenu.lua
  lfs_eng.hlf
  lfs_rus.hlf
)

foreach(elem ${MY_LIST})
  configure_file("src/${elem}" "${INSTALL_DIR}/plug/${elem}" COPYONLY)
endforeach()

add_custom_target(${PROJECT_NAME}_lang ALL
  minilua ${LUA_SHARE}/makelang.lua ${CMAKE_CURRENT_SOURCE_DIR}/src/lfs_lang.templ ${INSTALL_DIR}/plug
)

add_custom_target(${PROJECT_NAME}_files ALL
  COMMAND cp -rf "${CMAKE_CURRENT_SOURCE_DIR}/src/scripts" "${INSTALL_DIR}/plug/"
  COMMAND cp -rf "${CMAKE_CURRENT_SOURCE_DIR}/src/doc" "${INSTALL_DIR}/plug/"
)

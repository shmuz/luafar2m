project(sqlarc)

set(SOURCES
  src/GlobalInfo.c
  src/sqlarc.c
  src/lsqlite3.c
  ${FARSOURCE}/luafar/src/luaplug.c
)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DFUNC_OPENLIBS=luaopen_sqlarc")

add_library (${PROJECT_NAME} MODULE ${SOURCES})
set_property(TARGET ${PROJECT_NAME} PROPERTY C_STANDARD 11)

target_include_directories(sqlarc PRIVATE ${SQLITE3_INCLUDE_DIRS})
target_link_libraries(sqlarc ${SQLITE3_LIBRARIES})

set(EXPNAMES
  ANALYSE  CLOSEPLUGIN  CONFIGURE  DELETEFILES
  GETFILES  GETFINDDATA  GETOPENPLUGININFO  MAKEDIRECTORY
  OPENFILEPLUGIN  OPENPLUGIN  PROCESSEVENT  PROCESSHOSTFILE
  PROCESSKEY  PUTFILES  SETDIRECTORY  SETDIRECTORY
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
  sqlarc.lua
)

foreach(elem ${MY_LIST})
  configure_file("src/${elem}" "${INSTALL_DIR}/plug/${elem}" COPYONLY)
endforeach()

project(lftmp)

set(SOURCES
  src/GlobalInfo.c
  ${FARSOURCE}/luafar/src/luaplug.c
)

add_library (${PROJECT_NAME} MODULE ${SOURCES})
set_property(TARGET ${PROJECT_NAME} PROPERTY C_STANDARD 11)

set(EXPNAMES
  CLOSEPLUGIN  CONFIGURE  GETFINDDATA  GETOPENPLUGININFO
  OPENFILEPLUGIN  OPENPLUGIN  PROCESSEVENT  PROCESSKEY  PUTFILES
  SETDIRECTORY  SETFINDLIST
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
  target_link_libraries(${PROJECT_NAME} ${CMAKE_SOURCE_DIR}/luafar.so)
endif()

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
  configure_file("src/${elem}" "${INSTALL_DIR}/plug/${elem}" COPYONLY)
endforeach()

add_custom_target(${PROJECT_NAME}_lang ALL
  minilua ${LUA_SHARE}/makelang.lua ${CMAKE_CURRENT_SOURCE_DIR}/src/tmpp_lang.templ ${INSTALL_DIR}/plug
)

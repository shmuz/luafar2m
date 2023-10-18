set(CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/modules)

cmake_minimum_required (VERSION 3.1.0)

project (plugins)

string(ASCII 27 Esc)
set(ColorNormal "${Esc}[m")
set(ColorRed "${Esc}[1;31m")

# There must be a symlink far2m_src pointing to far2m source directory
set(FARSOURCE ${CMAKE_SOURCE_DIR}/far2m_src)
set(LUA_SHARE ${FARSOURCE}/luafar/lua_share)

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT CMAKE_BUILD_TYPE)
   set(CMAKE_BUILD_TYPE "Release")
endif()

if(NOT DEFINED CMAKE_INSTALL_PREFIX)
   if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
      set(CMAKE_INSTALL_PREFIX "/usr/local")
   elseif (${CMAKE_SYSTEM_NAME} MATCHES "FreeBSD")
      set(CMAKE_INSTALL_PREFIX "/usr/local")
   else()
      set(CMAKE_INSTALL_PREFIX "/usr")
   endif()
endif()

if (NOT DEFINED P_HIGHLIGHT)
   set(P_HIGHLIGHT "NO")
endif()

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -fPIC -Wno-unused-function -D_FILE_OFFSET_BITS=64") #  -fsanitize=address
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -std=c99 -fPIC -Wno-unused-function -D_FILE_OFFSET_BITS=64") #  -fsanitize=address
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS} -O2")
set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS} -O2")

if (NOT ${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -ffunction-sections -fdata-sections")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -ffunction-sections -fdata-sections")
    set(INSTALL_DIR ${CMAKE_BINARY_DIR}/install)
    if (NOT CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wl,--gc-sections")
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wl,--gc-sections")
    endif()
endif()

set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_C_VISIBILITY_PRESET hidden)

if(CMAKE_VERSION VERSION_GREATER "3.3")
    cmake_policy(SET CMP0063 NEW)
    cmake_policy(SET CMP0057 NEW)
endif()

find_package(LibLua REQUIRED)

include_directories(${LIBLUA_INCLUDE_DIRS})

add_executable (minilua ${FARSOURCE}/luafar/src/minilua.c)
target_link_libraries(minilua PRIVATE ${LIBLUA_LIBRARIES})

if (NOT DEFINED LF4ED OR LF4ED)
    message(STATUS "LF4ED plugin enabled")
    add_subdirectory (_lf4ed_)
else()
    message(STATUS "${ColorRed}LF4ED plugin disabled due to LF4ED=${LF4ED}${ColorNormal}")
    install(CODE "
        execute_process(COMMAND ${CMAKE_COMMAND} -E rm -f ${CMAKE_INSTALL_PREFIX}/lib/far2m/Plugins/luafar/lf4ed/plug/lf4ed.far-plug-wide)
        " COMPONENT system)
endif()

if (NOT DEFINED LFHISTORY OR LFHISTORY)
    message(STATUS "LFHISTORY plugin enabled")
    add_subdirectory (_lfhistory_)
else()
    message(STATUS "${ColorRed}LFHISTORY plugin disabled due to LFHISTORY=${LFHISTORY}${ColorNormal}")
    install(CODE "
        execute_process(COMMAND ${CMAKE_COMMAND} -E rm -f ${CMAKE_INSTALL_PREFIX}/lib/far2m/Plugins/luafar/lfhistory/plug/lfhistory.far-plug-wide)
        " COMPONENT system)
endif()

if (NOT DEFINED LFSEARCH OR LFSEARCH)
    message(STATUS "LFSEARCH plugin enabled")
    add_subdirectory (_lfsearch_)
else()
    message(STATUS "${ColorRed}LFSEARCH plugin disabled due to LFSEARCH=${LFSEARCH}${ColorNormal}")
    install(CODE "
        execute_process(COMMAND ${CMAKE_COMMAND} -E rm -f ${CMAKE_INSTALL_PREFIX}/lib/far2m/Plugins/luafar/lfsearch/plug/lfsearch.far-plug-wide)
        " COMPONENT system)
endif()

if (NOT DEFINED HLFVIEWER OR HLFVIEWER)
    message(STATUS "HLFVIEWER plugin enabled")
    add_subdirectory (_hlfviewer_)
else()
    message(STATUS "${ColorRed}HLFVIEWER plugin disabled due to HLFVIEWER=${HLFVIEWER}${ColorNormal}")
    install(CODE "
        execute_process(COMMAND ${CMAKE_COMMAND} -E rm -f ${CMAKE_INSTALL_PREFIX}/lib/far2m/Plugins/luafar/hlfviewer/plug/hlfviewer.far-plug-wide)
        " COMPONENT system)
endif()

if (NOT DEFINED LFTMP OR LFTMP)
    message(STATUS "LFTMP plugin enabled")
    add_subdirectory (_lftmp_)
else()
    message(STATUS "${ColorRed}LFTMP plugin disabled due to LFTMP=${LFTMP}${ColorNormal}")
    install(CODE "
        execute_process(COMMAND ${CMAKE_COMMAND} -E rm -f ${CMAKE_INSTALL_PREFIX}/lib/far2m/Plugins/luafar/lftmp/plug/lftmp.far-plug-wide)
        " COMPONENT system)
endif()

if (NOT DEFINED LUAPANEL OR LUAPANEL)
    message(STATUS "LUAPANEL plugin enabled")
    add_subdirectory (_luapanel_)
else()
    message(STATUS "${ColorRed}LUAPANEL plugin disabled due to LUAPANEL=${LUAPANEL}${ColorNormal}")
    install(CODE "
        execute_process(COMMAND ${CMAKE_COMMAND} -E rm -f ${CMAKE_INSTALL_PREFIX}/lib/far2m/Plugins/luafar/luapanel/plug/luapanel.far-plug-wide)
        " COMPONENT system)
endif()

if (NOT DEFINED POLYGON OR POLYGON)
    find_package(Sqlite3)
    if (Sqlite3_FOUND)
        message(STATUS "POLYGON plugin enabled")
        add_subdirectory(_polygon_)
    else()
        message(STATUS "${ColorRed}POLYGON plugin disabled due to not found sqlite3 package${ColorNormal}")
    endif()
else()
    message(STATUS "${ColorRed}POLYGON plugin disabled due to POLYGON=${POLYGON}${ColorNormal}")
    install(CODE "
        execute_process(COMMAND ${CMAKE_COMMAND} -E rm -f ${CMAKE_INSTALL_PREFIX}/lib/far2m/Plugins/luafar/polygon/plug/polygon.far-plug-wide)
        " COMPONENT system)
endif()

if (DEFINED HIGHLIGHT AND HIGHLIGHT)
    message(STATUS "HIGHLIGHT plugin enabled")
    add_subdirectory (_highlight_)
else()
    message(STATUS "${ColorRed}HIGHLIGHT plugin disabled, use -DHIGHLIGHT=yes if you need it${ColorNormal}")
    install(CODE "
        execute_process(COMMAND ${CMAKE_COMMAND} -E rm -f ${CMAKE_INSTALL_PREFIX}/lib/far2m/Plugins/luafar/highlight/plug/highlight.far-plug-wide)
        " COMPONENT system)
endif()

install(DIRECTORY "${INSTALL_DIR}/" DESTINATION "lib/far2m/Plugins/luafar" USE_SOURCE_PERMISSIONS COMPONENT base FILES_MATCHING
    PATTERN "*.far-plug-*"
    PATTERN "highlight/plug/syntaxes"  EXCLUDE
    PATTERN "lf4ed/plug/scripts"       EXCLUDE
    PATTERN "lfsearch/plug/doc"        EXCLUDE
    PATTERN "lfsearch/plug/scripts"    EXCLUDE
    PATTERN "polygon/plug/modules"     EXCLUDE
)

install(DIRECTORY "${INSTALL_DIR}/" DESTINATION "share/far2m/Plugins/luafar" USE_SOURCE_PERMISSIONS COMPONENT base FILES_MATCHING
    PATTERN "*.far-plug-*" EXCLUDE
    PATTERN "*"
)

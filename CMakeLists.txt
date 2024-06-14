set(CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/modules)

cmake_minimum_required (VERSION 3.1.0)

project (plugins)

# FARSOURCE must not be defined via $HOME
set(FARSOURCE ${CMAKE_SOURCE_DIR}/../far2m)
set(LUA_SHARE ${FARSOURCE}/luafar/lua_share)

string(ASCII 27 Esc)
set(ColorNormal "${Esc}[m")
set(ColorRed "${Esc}[1;31m")

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
include_directories(${FARSOURCE}/WinPort)

add_executable (minilua ${FARSOURCE}/luafar/src/minilua.c)
target_link_libraries(minilua PRIVATE ${LIBLUA_LIBRARIES})

function(AddPlugin Name Active)
  string(TOUPPER ${Name} Var)
  if ((DEFINED ${Var} AND ${Var}) OR (NOT DEFINED ${Var} AND ${Active}))
      message(STATUS "${Var} plugin enabled")
      add_subdirectory (Plugins/${Name})
  else()
      if (${Active})
          message(STATUS "${ColorRed}${Var} plugin disabled due to ${Var}=${${Var}}${ColorNormal}")
      else()
          message(STATUS "${ColorRed}${Var} plugin disabled, use -D${Var}=yes if you need it${ColorNormal}")
      endif()
      install(CODE "
          execute_process(COMMAND ${CMAKE_COMMAND} -E rm -f ${CMAKE_INSTALL_PREFIX}/lib/far2m/Plugins/luafar/${Name}/plug/${Name}.far-plug-wide)
          " COMPONENT system)
  endif()
endfunction()

AddPlugin( filegen     0 )
AddPlugin( highlight   0 )
AddPlugin( lf4ed       1 )
AddPlugin( lfhistory   1 )
AddPlugin( lfsearch    1 )
AddPlugin( lftmp       1 )
AddPlugin( luapanel    1 )

if (NOT DEFINED POLYGON OR POLYGON)
    find_package(Sqlite3)
    if (Sqlite3_FOUND)
        AddPlugin(polygon 1)
    else()
        message(STATUS "${ColorRed}POLYGON plugin disabled due to not found sqlite3 package${ColorNormal}")
    endif()
else()
    AddPlugin(polygon 0)
endif()

if (NOT DEFINED SQLARC OR SQLARC)
    find_package(Sqlite3)
    if (Sqlite3_FOUND)
        AddPlugin(sqlarc 1)
    else()
        message(STATUS "${ColorRed}SQLARC plugin disabled due to not found sqlite3 package${ColorNormal}")
    endif()
else()
    AddPlugin(sqlarc 0)
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

cmake_minimum_required (VERSION 3.1.0)

project (plugins)

set(FARSOURCE ~/far2m)
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

if (NOT DEFINED LUAINC)
    foreach(PP "luajit-2.1" "luajit-2.0" "lua5.1")
        find_path(INC ${PP}/lua.h)
        if (NOT ${INC} STREQUAL INC-NOTFOUND)
            set(LUAINC ${INC}/${PP} CACHE INTERNAL "Lua #include path" FORCE)
            include_directories(${LUAINC})
            break()
        endif()
    endforeach()
    if (NOT DEFINED LUAINC)
        message(FATAL_ERROR "${ColorRed}Neither of LuaJIT/Lua5.1 #include path was found${ColorNormal}")
    endif()
endif()

find_library(LUALIB NAMES luajit-5.1 lua5.1)
if (${LUALIB} STREQUAL LUALIB-NOTFOUND)
  message(FATAL_ERROR "${ColorRed}Neither luajit nor lua5.1 was found${ColorNormal}")
endif()

add_executable (minilua ${FARSOURCE}/luafar/src/minilua.c)
target_link_libraries(minilua PRIVATE ${LUALIB})

add_subdirectory (_lf4ed_)

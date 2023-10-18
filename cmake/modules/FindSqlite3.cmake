#  SQLITE3_FOUND     - System has sqlite3
#  SQLITE3_INCLUDE_DIR - The sqlite3 include directories
#  SQLITE3_LIBRARIES    - The libraries needed to use sqlite3

find_path(SQLITE3_INCLUDE_DIR
    NAMES
      sqlite3.h
    PATHS
      /usr/include
      /usr/local/include
      /opt/local/include
)

find_library(SQLITE3_LIBRARY
    NAMES
      libsqlite3
      sqlite3
    PATHS
      /usr/lib
      /usr/local/lib
      /opt/local/lib
)

# handle the QUIETLY and REQUIRED arguments and set NF_FOUND to TRUE
# if all listed variables are TRUE
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Sqlite3
	REQUIRED_VARS SQLITE3_LIBRARY SQLITE3_INCLUDE_DIR
)

set(SQLITE3_LIBRARIES ${SQLITE3_LIBRARY})
set(SQLITE3_INCLUDE_DIRS ${SQLITE3_INCLUDE_DIR})
mark_as_advanced(SQLITE3_INCLUDE_DIR SQLITE3_LIBRARY)

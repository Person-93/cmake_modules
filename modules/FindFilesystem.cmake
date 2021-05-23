#[=======================================================================[.rst:

FindFilesystem
--------------

Find any libraries that need to be linked with to use ``std::filesystem``.

.. code-block:: cmake

  find_package(Filesystem REQUIRED)

  add_executable(my-program main.cpp)
  target_link_libraries(my-program PRIVATE std::filesystem)

Imported Targets
^^^^^^^^^^^^^^^^

The following :prop_tgt:`IMPORTED` target may be defined:

``std::filesystem``
  The ``std::filesystem`` imported target is defined when  the C++ filesystem library
  has been found.

  .. note::
    This target has ``cxx_std_17`` as an :prop_tgt:`INTERFACE` feature. Linking to
    this target will automatically enable C++17 if no later standard version is
    already required on the linking target.

#]=======================================================================]

if (TARGET std::filesystem)
    return ()
endif ()

cmake_minimum_required (VERSION 3.10)

include (CMakePushCheckState)
include (CheckIncludeFileCXX)

# If we're not cross-compiling, try to run test executables. Otherwise, assume that
# compile + link is a sufficient check.
if (CMAKE_CROSSCOMPILING)
    include (CheckCXXSourceCompiles)
    macro (_filesystem_check_cxx_source code var)
        check_cxx_source_compiles ("${code}" ${var})
    endmacro ()
else ()
    include (CheckCXXSourceRuns)
    macro (_filesystem_check_cxx_source code var)
        check_cxx_source_runs ("${code}" ${var})
    endmacro ()
endif ()

cmake_push_check_state ()

set (CMAKE_CXX_STANDARD 17)
unset (have_header)
unset (can_link)

check_include_file_cxx (filesystem have_header)

if (have_header)
    set (
        CODE
        [[
        #include <cstdlib>
        #include <filesystem>

        int main() {
            auto cwd = std::filesystem::current_path();
            printf("%s", cwd.c_str());
            return EXIT_SUCCESS;
        }
        ]]
        )

    _filesystem_check_cxx_source ("${CODE}" can_link)
    unset (FS_LIBS)

    if (NOT can_link)
        set (PREV_LIBRARIES ${CMAKE_REQUIRED_LIBRARIES})
        set (FS_LIBS "-lstdc++fs")
        set (CMAKE_REQUIRED_LIBRARIES ${PREV_LIBRARIES} ${FS_LIBS})
        _filesystem_check_cxx_source ("${CODE}" can_link)

        if (NOT can_link)
            set (FS_LIBS "-lc++fs")
            set (CMAKE_REQUIRED_LIBRARIES ${PREV_LIBRARIES} ${FS_LIBS})
            _filesystem_check_cxx_source ("${CODE}" CXX_FILESYSTEM_CPPFS_NEEDED)
        endif ()
    endif ()

    if (can_link)
        add_library (std::filesystem INTERFACE IMPORTED)
        set_property (
            TARGET std::filesystem APPEND PROPERTY INTERFACE_COMPILE_FEATURES
                                                   cxx_std_17
            )
        set_property (
            TARGET std::filesystem APPEND PROPERTY INTERFACE_LINK_LIBRARIES ${FS_LIBS}
            )
    endif ()
endif ()

cmake_pop_check_state ()

if (Filesystem_FIND_REQUIRED AND NOT can_link)
    message (FATAL_ERROR "Cannot run simple program using std::filesystem")
endif ()

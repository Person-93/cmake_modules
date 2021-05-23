cmake_minimum_required (VERSION 3.3)
if (DEFINED CMAKE_TOOLCHAIN_FILE)
    message (STATUS "Using toolchain file: ${CMAKE_TOOLCHAIN_FILE}")
endif ()
list (APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/modules)

get_directory_property (has_parent PARENT_DIRECTORY)
if (has_parent)
    set (CMAKE_MODULE_PATH "${CMAKE_MODULE_PATH}" PARENT_SCOPE)
endif ()

include (ParseIni)
parse_ini (info.ini info)

project ("${info_project_name}" LANGUAGES)
option (PERSON93_CMAKE_MODULES_BUILD_DOCS OFF)

if (PERSON93_CMAKE_MODULES_BUILD_DOCS)
    message (STATUS "${PROJECT_NAME} documentation enabled")
    list (APPEND CMAKE_MESSAGE_INDENT "  ")
    find_package (Sphinx REQUIRED)
    include (BuildConfigureFile)

    add_subdirectory (docs)
    set_property (DIRECTORY docs PROPERTY EXCLUDE_FROM_ALL ON)
    list (POP_BACK CMAKE_MESSAGE_INDENT)
endif ()

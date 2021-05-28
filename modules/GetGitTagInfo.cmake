#[=======================================================================[.rst:
GetGitTagInfo
-------------

This module contains functions for working with git describe and semver strings.

Functions
^^^^^^^^^

#]=======================================================================]

cmake_policy (PUSH)
cmake_minimum_required (VERSION 3.15)

if (NOT GIT_FOUND)
    find_package (Git QUIET)
    if (NOT GIT_FOUND)
        message (FATAL_ERROR "Git was not found")
    endif ()
endif ()

function (_git_describe var)
    execute_process (
        COMMAND ${GIT_EXECUTABLE} describe ${ARGN}
        WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}" RESULT_VARIABLE result
        OUTPUT_VARIABLE output ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE
        )
    if (NOT result EQUAL 0)
        set (output "${output}-${result}-NOTFOUND")
    endif ()
    set (${var} "${output}" PARENT_SCOPE)
endfunction ()

#[=======================================================================[.rst:

.. command:: git_get_head_revision

  This function gets the git revision information and store it in the given variable.
  If git errors out trying to get the info, the variable will be set to git's output
  followed by ``-NOTFOUND``.

  .. code-block:: cmake

    git_get_head_revision(<variable-name>)

#]=======================================================================]

function (git_get_head_revision var)
    _git_describe (tag --tags --always --dirty)
    set (${var} "${tag}" PARENT_SCOPE)
endfunction ()

#[=======================================================================[.rst:

.. command:: git_get_head_tag

  This function gets the latest tag relative to the ``HEAD``.

  .. code-block:: cmake

    git_get_head_tag(<variable-name>)

#]=======================================================================]

function (git_get_head_tag var)
    _git_describe (tag --tags --abbrev=0)
    set (${var} "${tag}" PARENT_SCOPE)
endfunction ()

macro (_set_semver_vars_exit_error message)
    message (WARNING "${message}")
    # cmake-lint: disable=C0103
    set (${args_OUTPUT} NOTFOUND PARENT_SCOPE)
    set (${args_OUTPUT}_MAJOR NOTFOUND PARENT_SCOPE)
    set (${args_OUTPUT}_MINOR NOTFOUND PARENT_SCOPE)
    set (${args_OUTPUT}_PATCH NOTFOUND PARENT_SCOPE)
    set (${args_OUTPUT}_PRERELEASE NOTFOUND PARENT_SCOPE)
    return ()
endmacro ()

#[=======================================================================[.rst:

.. command set_semver_vars

  This function takes an optional input and sets several variables. The input should
  be an optionally prefixed semver string. The outputs will be un-prefixed semver and
  each part of the version separately. If the input is not present it will use the
  latest head revision.

  code-block:: cmake

    set_semver_vars([INPUT <semver-string>]
                   OUTPUT <variable-name>
                   [TAG_PREFIXES <prefix>...])

   The ``INPUT`` should be an optionally prefixed semver string. If it is not present
   the output of ``git_get_head_revision`` will be used.

   The ``OUTPUT`` should be a valid variable name. It will be be set to the full semver
   string with the optional prefix removed. It will also be used as the prefix for the
   individual parts of the semver string. For example, if ``OUTPUT`` is ``SEMVER``, the
   function will set the following variables ``SEMVER`` will be the full semver string.
   ``SEMVER_MAJOR`` will be the major version. ``SEMVER_MINOR`` will be the minor
   version. ``SEMVER_PRERELEASE`` will be the prerelease tag or ``NOTFOUND``. If the
   input is not a valid semver string, all the variables will be set to ``NOTFOUND``.
   If build metadata is present it will invalidate the entire string. The rationale is
   that build metadata should only be applied to build artifacts, not source control.

   The ``TAG_PREFIXES`` is an optional list of strings which the semver string might be
   prefixed with. Many projects tag their release like ``v0.1.0``. For projects like
   that this argument should be ``v`` and the ``v`` prefix will be ignored.

#]=======================================================================]

function (set_semver_vars)
    set (options "")
    set (single_value INPUT OUTPUT)
    set (multi_value TAG_PREFIXES)
    cmake_parse_arguments (args "${options}" "${single_value}" "${multi_value}" ${ARGN})

    if (NOT args_OUTPUT)
        message (FATAL_ERROR "set_semver_args needs OUTPUT argument")
    endif ()

    if (args_UNPARSED_ARGUMNENTS)
        message (FATAL_ERROR "set_semver args called with invalid arguments: "
                             "${_args_UNPARSED_ARGUMNENTS}"
                 )
    endif ()

    if (NOT args_INPUT)
        git_get_head_revision (args_INPUT)
        if (NOT args_INPUT)
            _set_semver_vars_exit_error (
                "set_semver_vars called without input "
                "and failed to get the current tag: ${_args_INPUT}"
                )
        endif ()
    endif ()

    unset (prefixes)
    list (JOIN args_TAG_PREFIXES | prefixes)

    unset (full_pattern)
    # the regex was adapted from
    # https://semver.org/#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string
    string (
        APPEND
        full_pattern
        "^(${prefixes})?"
        [[(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*)(\.(0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*))*))*$]]
        )
    string (REGEX MATCH "${full_pattern}" semver_string "${args_INPUT}")
    if (NOT semver_string)
        _set_semver_vars_exit_error (
            "${args_INPUT} is not a semver string ( build metadata is not allowed )"
            )
    endif ()

    set (major "${CMAKE_MATCH_2}")
    set (minor "${CMAKE_MATCH_3}")
    set (patch "${CMAKE_MATCH_4}")
    set (prerelease "${CMAKE_MATCH_6}")
    set (full "${major}.${minor}.${patch}")
    if (tweak)
        string (APPEND full "-${tweak}")
    endif ()

    # cmake-lint: disable=C0103
    set (${args_OUTPUT}_MAJOR "${major}" PARENT_SCOPE)
    set (${args_OUTPUT}_MINOR "${minor}" PARENT_SCOPE)
    set (${args_OUTPUT}_PATCH "${patch}" PARENT_SCOPE)
    set (${args_OUTPUT}_PRERELEASE "${prerelease}" PARENT_SCOPE)
    set (${args_OUTPUT} "${full}" PARENT_SCOPE)
endfunction ()

#[=======================================================================[.rst:

.. command:: git_get_dependency_files

  This function returns a list of files which can be listed as dependencies
  of a custom target that needs to be rerun when the ``HEAD`` is modified.
  (i.e. new commits)

  .. code-block:: cmake

    git_get_dependency_files(my_var)
    add_custom_target(some_target DEPENDS ${my_var})

#]=======================================================================]

function (git_get_dependency_files var)
    set (git_deps "")

    execute_process (
        COMMAND "${GIT_EXECUTABLE}" rev-parse --absolute-git-dir
        WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE git_dir
        OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_STRIP_TRAILING_WHITESPACE
        )
    if (NOT result EQUAL 0)
        message (FATAL_ERROR "${result}-${git_dir}")
    endif ()
    list (APPEND git_deps "${git_dir}/logs/HEAD")

    set (${var} "${git_deps}" PARENT_SCOPE)
endfunction ()

#[=======================================================================[.rst:

.. command:: git_add_configure_dependency

  This function causes the current project to be reconfigured whenever the
  ``HEAD`` is modified. (i.e. new commits)

  .. code-block:: cmake

    git_add_configure_dependency()

#]=======================================================================]

function (git_add_configure_dependency)
    git_get_dependency_files (files)
    set_property (
        DIRECTORY "${PROJECT_SOURCE_DIR}" APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
                                                          ${files}
        )
endfunction ()

cmake_policy (POP)

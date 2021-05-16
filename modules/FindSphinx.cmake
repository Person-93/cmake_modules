#[=======================================================================[.rst:

FindSphinx
----------

Sphinx is a documentation generation tool (see https://www.sphinx-doc.org/).

Result Variables
^^^^^^^^^^^^^^^^

This will define the following variables:

.. variable:: SPHINX_FOUND

  True if the system has sphinx.

.. variable:: SPHINX_EXECUTABLE

  The path to the sphinx-build executable.

.. variable:: SPHINX_VERSION

  The version reported by ``sphinx-build --version``.

Functions
^^^^^^^^^

#]=======================================================================]

cmake_policy (PUSH)
cmake_minimum_required (VERSION 3.9)

find_program (
    SPHINX_EXECUTABLE NAMES sphinx-build
    DOC "Sphinx Documentation Builder (sphinx-doc.org)"
    )
mark_as_advanced (SPHINX_EXECUTABLE)
if (SPHINX_EXECUTABLE)
    set (SPHINX_FOUND TRUE)
    execute_process (
        COMMAND ${SPHINX_EXECUTABLE} --version OUTPUT_VARIABLE SPHINX_VERSION
        RESULT_VARIABLE sphinx_version_result
        )
    if (sphinx_version_result)
        message (WARNING "Unable to determine sphinx version: ${sphinx_version_result}")
    else ()
        string (REPLACE "sphinx-build " "" SPHINX_VERSION "${SPHINX_VERSION}")
    endif ()

    if (NOT TARGET Sphinx::sphinx)
        add_executable (Sphinx::sphinx IMPORTED GLOBAL)
        set_target_properties (
            Sphinx::sphinx PROPERTIES IMPORTED_LOCATION "${SPHINX_EXECUTABLE}"
            )
    endif ()
endif ()

include (FindPackageHandleStandardArgs)
find_package_handle_standard_args (Sphinx REQUIRED_VARS SPHINX_EXECUTABLE)

#[=======================================================================[.rst:
.. command:: sphinx_add_docs

  This function is intended as a convenience for adding a target
  generating documentation with Sphinx.

  .. code-block:: cmake

    sphinx_add_docs(targetName
                    [ALL]
                    [SOURCE <documentation-source-dir>]
                    [BUILD <documentation-build-dir>]
                    [CONFIG <documentation-config-dir>]
                    [DEPENDS <dependency>...]
    )

  If ``ALL`` is present, the target will be included in all.

  The ``SOURCE`` argument should be the documentation source directory. Defaults to
  ``${CMAKE_CURRENT_SOURCE_DIR}``.

  The ``BUILD`` argument should be the documentation build directory. Defaults to
  ``${CMAKE_CURRENT_BINARY_DIR}``.

  The ``CONFIG`` argument should be the documentation configuration directory.
  Defaults to the ``SOURCE`` directory.

  The ``DEPENDS`` argument is an optional list of files or targets that the
  documentation depends on.

#]=======================================================================]

function (sphinx_add_docs target)
    if (NOT TARGET Sphinx::sphinx)
        message (
            FATAL_ERROR
                "Sphinx was not found, needed by sphinx_add_docs for target ${target}"
            )
    endif ()

    set (options ALL)
    set (single_value SOURCE BUILD CONFIG)
    set (multi_value DEPENDS)
    cmake_parse_arguments (args "${options}" "${single_value}" "${multi_value}" ${ARGN})

    if (NOT DEFINED args_SOURCE)
        set (args_SOURCE "${CMAKE_CURRENT_SOURCE_DIR}")
    endif ()

    if (NOT DEFINED args_BUILD)
        set (args_BUILD "${CMAKE_CURRENT_BINARY_DIR}")
    endif ()

    if (NOT DEFINED args_CONFIG)
        set (args_CONFIG "${args_SOURCE}")
    endif ()

    unset (maybe_all)
    if (args_ALL)
        set (maybe_all ALL)
    endif ()

    add_custom_target (
        ${target}
        ${maybe_all}
        COMMAND Sphinx::sphinx -W -c ${args_CONFIG} ${args_SOURCE} ${args_BUILD}
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        COMMENT "Generating documentation with sphinx"
        DEPENDS ${args_DEPENDS}
        VERBATIM
        )
endfunction ()

cmake_policy (POP)

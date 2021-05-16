#[=======================================================================[.rst:

BuildConfigureFile
------------------

This module adds a function similar to ``configure_file`` but it runs at build time.

Functions
^^^^^^^^^

#]=======================================================================]

cmake_policy (PUSH)
cmake_minimum_required (VERSION 3.4)

#[=======================================================================[.rst:

.. command:: build_configure_file

  This function creates a rule for generating a file at build time. The file is
  generated in a way similar to the command ``configure_file``. The file can be
  used as a dependency of a custom target in the same directory.

  .. code-block:: cmake

    build_configure_file(INPUT <input-file>
                         OUTPUT <output-file>
                         VARIABLES <variable-name>...
                         [DEPENDS <dependency>...]
                         [@ONLY]
                         [COPYONLY]
                         [ESCAPE_QUOTES])

 The ``INPUT`` is the file to read from. If it's a relative path it will be
 relative to ``${CMAKE_CURRENT_SOURCE_DIR}``.

 The ``OUTPUT`` is the file to generate. If it's a relative path it will be
 relative to ``${CMAKE_CURRENT_BINARY_DIR}``.

 The ``VARIABLES`` is a list of variables that should be made visible to the
 configuration. This is needed because by default variables don't exist any
 more at build time. They have to be explicitly stored.

 The ``DEPENDS`` is a list of files or targets that the rule should depend on.

 ``@ONLY``, ``COPYONLY``, and ``ESCAPE_QUOTES`` work the same way as they do in
 ``configure_file``.

#]=======================================================================]

function (build_configure_file)
    set (options COPYONLY @ONLY ESCAPE_QUOTES)
    set (single_value INPUT OUTPUT)
    set (multi_value VARIABLES DEPENDS)
    cmake_parse_arguments (args "${options}" "${single_value}" "${multi_value}" ${ARGN})

    if (NOT DEFINED args_INPUT)
        message (FATAL_ERROR "build_configure missing INPUT")
    endif ()

    if (NOT DEFINED args_OUTPUT)
        message (FATAL_ERROR "build_configure missing OUTPUT")
    endif ()

    list (LENGTH args_VARIABLES len)
    if (len EQUAL 0)
        message (FATAL_ERROR "build_configure needs a list of variables make "
                             "sure to specify the VARIABLES argument"
                 )
    endif ()

    if (DEFINED args_UNPARSED_ARGUMENTS)
        message (
            FATAL_ERROR
                "build_configure passed invalid argument(s): ${args_UNPARSED_ARGUMENTS}"
            )
    endif ()

    unset (args_copyonly)
    if (args_COPYONLY)
        set (maybe_copyonly COPYONLY)
    endif ()

    unset (maybe_only)
    if (args_@ONLY)
        set (maybe_only @ONLY)
    endif ()

    unset (maybe_escape_quotes)
    if (args_ESCAPE_QUOTES)
        set (maybe_escape_quotes ESCAPE_QUOTES)
    endif ()

    set (text "")
    foreach (variable ${args_VARIABLES})
        string (APPEND text "set ( \"${variable}\" \"${${variable}}\" )\n")
    endforeach ()

    get_filename_component (absolute_input "${args_INPUT}" ABSOLUTE)
    get_filename_component (
        absolute_output "${args_OUTPUT}" ABSOLUTE BASE_DIR
        "${CMAKE_CURRENT_BINARY_DIR}"
        )
    file (RELATIVE_PATH relative_input "${CMAKE_CURRENT_SOURCE_DIR}"
          "${absolute_input}"
          )

    string (APPEND text "configure_file ( \"${absolute_input}\" \"${absolute_output}\" \
        ${maybe_copyonly} ${maybe_only} ${maybe_escape_quotes} )\n"
            )
    set (temp_file
         "${CMAKE_CURRENT_BINARY_DIR}/${relative_input}.build_configure_file.temp.cmake"
         )
    file (WRITE "${temp_file}" "${text}")

    set (script_file
         "${CMAKE_CURRENT_BINARY_DIR}/${relative_input}.build_configure_file.cmake"
         )
    configure_file ("${temp_file}" "${script_file}" COPYONLY)

    add_custom_command (
        OUTPUT "${args_OUTPUT}" DEPENDS "${args_INPUT}" ${args_DEPENDS} "${script_file}"
        COMMAND ${CMAKE_COMMAND} -P "${script_file}"
        COMMENT "Configuring file ${args_INPUT}"
        )
endfunction ()

cmake_policy (POP)

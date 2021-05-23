#[=======================================================================[.rst:
ParseIni
--------

This module adds a function to parse INI files

Functions
^^^^^^^^^

#]=======================================================================]

# TODO the regex patterns allows ']' in middle of the text
# https://discourse.cmake.org/t/regex-match-exclude-character/3348

cmake_policy (PUSH)
cmake_minimum_required (VERSION 3.9)

function (_parse_section_header line)
    string (REPLACE)
endfunction ()

macro (_parse_ini_fatal_error message)
    math (EXPR index "${index}+1")
    message (FATAL_ERROR "${message}\n${file}:${index} \"${line}\"")
endmacro ()

#[=======================================================================[.rst:

.. command:: parse_ini

  This function parses an ini file and it creates a variable for each key-value
  pair that if finds. It produces a fatal error if the file is invalid.

  .. code-block:: cmake

    parse_ini(<file> <prefix>)

  The ``file`` argument should be an absolute or relative path to the ini file.

  The ``prefix`` argument should be a string that will be used as a prefix for
  each variable.

  Given this file...

  .. code-block::

    # file.ini
    key = value
    multi word key = multi word value
    [config]
    key = value

  and this call...

  .. code-block:: cmake

    parse_ini(file.ini info)

  THat is equivalent to the following:

  .. code-block:: cmake

    set(info_key value)
    set(info_multi_word_key "multi word value")
    set(info_config_key value)

  .. warning::

    If a section or key name contains a ']' it will incorrectly parse it as part of
    the name. It should really fail to parse.

#]=======================================================================]

function (parse_ini file prefix)
    file (STRINGS "${file}" content)

    unset (current_section)
    set (discovered_sections "")
    set (discovered_keys "")
    list (LENGTH content len)
    math (EXPR len "${len}-1")
    # use range-based loop instead of list-based because list-based skips blank lines
    foreach (index RANGE ${len})
        list (GET content ${index} line)

        if (line MATCHES "^[;#]" OR line MATCHES "^ *$") # comment or blank line
            continue ()
        elseif (line MATCHES "^\\[(([^ \t\r\n\\[]+)( *[^ \t\r\n\\[]+)+)\\]$") # section
            # tested at https://regex101.com/r/RzHF72/1

            set (current_section "${CMAKE_MATCH_1}")
            if (current_section IN_LIST discovered_sections)
                _parse_ini_fatal_error ("Duplicate section in ini file")
            endif ()
            list (APPEND discovered_sections "${current_section}")
            set (discovered_keys "")

        elseif (
            # key-value pair
            line
            MATCHES
            "^(([^ \t\r\n:=\\[]+)( *[^ \t\r\n:=\\[]+)+) *[:=] *([^ \t\r\n\\[]+( *[^ \t\r\n=\\[]+)*)$"
            )
            # tested at https://regex101.com/r/xadrha/2

            set (key "${CMAKE_MATCH_1}")
            set (value "${CMAKE_MATCH_4}")
            if (key IN_LIST discovered_keys)
                _parse_ini_fatal_error ("Duplicate key in ini file")
            endif ()
            list (APPEND discovered_keys "${key}")

            set (full_name "${prefix}_")
            if (DEFINED current_section)
                string (APPEND full_name "${current_section}_")
            endif ()
            string (APPEND full_name "${key}")
            string (REPLACE " " _ full_name "${full_name}")

            set (${full_name} "${value}" PARENT_SCOPE)
        else ()
            _parse_ini_fatal_error ("Invalid line in ini file")
        endif ()
    endforeach ()
endfunction ()

cmake_policy (POP)

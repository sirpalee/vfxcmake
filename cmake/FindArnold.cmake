# - Arnold finder module
# This module searches for a valid Arnold installation.
#
# Variables that will be defined:
# ARNOLD_FOUND              Defined if a Arnold installation has been detected
# ARNOLD_LIBRARY            Path to ai library (for backward compatibility)
# ARNOLD_LIBRARIES          Path to ai library
# ARNOLD_INCLUDE_DIR        Path to the include directory (for backward compatibility)
# ARNOLD_INCLUDE_DIRS       Path to the include directory
# ARNOLD_KICK               Path to kick
# ARNOLD_PYKICK             Path to pykick
# ARNOLD_MAKETX             Path to maketx
# ARNOLD_OSLC               Path to the osl compiler
# ARNOLD_OSL_HEADER_DIR     Path to the osl headers include directory (for backward compatibility)
# ARNOLD_OSL_HEADER_DIRS    Path to the osl headers include directory
# ARNOLD_VERSION_ARCH_NUM   Arch version of Arnold
# ARNOLD_VERSION_MAJOR_NUM  Major version of Arnold
# ARNOLD_VERSION_MINOR_NUM  Minor version of Arnold
# ARNOLD_VERSION_FIX        Fix version of Arnold
# ARNOLD_VERSION            Version of Arnold
# arnold_compile_osl        Function to compile / install .osl files
#   QUIET                   Quiet builds
#   VERBOSE                 Verbose builds
#   INSTALL                 Install compiled files into DESTINATION
#   INSTALL_SOURCES         Install sources into DESTINATION_SOURCES
#   OSLC_FLAGS              Extra flags for OSLC
#   DESTINATION             Destination for compiled files
#   DESTINATION_SOURCES     Destination for source files
#   INCLUDES                Include directories for oslc
#   SOURCES                 Source osl files
#
#
# Naming convention:
#  Local variables of the form foo
#  Input variables from CMake of the form ARNOLD_FOO
#  Output variables of the form ARNOLD_FOO
#

find_library(ARNOLD_LIBRARY
    NAMES ai
    PATHS $ENV{ARNOLD_HOME}/bin
    DOC "Arnold library")

find_file(ARNOLD_KICK
    names kick
    PATHS $ENV{ARNOLD_HOME}/bin
    DOC "Arnold kick executable")

find_file(ARNOLD_PYKICK
    names pykick
    PATHS $ENV{ARNOLD_HOME}/python/pykikc
    DOC "Arnold pykick executable")

find_file(ARNOLD_MAKETX
    names maketx
    PATHS $ENV{ARNOLD_HOME}/bin
    DOC "Arnold maketx executable")

find_path(ARNOLD_INCLUDE_DIR ai.h
    PATHS $ENV{ARNOLD_HOME}/include
    DOC "Arnold include path")

find_path(ARNOLD_PYTHON_DIR arnold/ai_allocate.py
    PATHS $ENV{ARNOLD_HOME}/python
    DOC "Arnold python bindings path")

find_file(ARNOLD_OSLC
    names oslc
    PATHS $ENV{ARNOLD_HOME}/bin
    DOC "Arnold flavoured oslc")

find_path(ARNOLD_OSL_HEADER_DIR stdosl.h
    PATHS $ENV{ARNOLD_HOME}/osl/include
    DOC "Arnold flavoured osl headers")

set(ARNOLD_LIBRARIES ${ARNOLD_LIBRARY})
set(ARNOLD_INCLUDE_DIRS ${ARNOLD_INCLUDE_DIR})
set(ARNOLD_PYTHON_DIRS ${ARNOLD_PYTHON_DIR})
set(ARNOLD_OSL_HEADER_DIRS ${ARNOLD_OSL_HEADER_DIR})

if(ARNOLD_INCLUDE_DIR AND EXISTS "${ARNOLD_INCLUDE_DIR}/ai_version.h")
    foreach(comp ARCH_NUM MAJOR_NUM MINOR_NUM FIX)
        file(STRINGS
            ${ARNOLD_INCLUDE_DIR}/ai_version.h
            TMP
            REGEX "#define AI_VERSION_${comp} .*$")
        string(REGEX MATCHALL "[0-9]+" ARNOLD_VERSION_${comp} ${TMP})
    endforeach()
    set(ARNOLD_VERSION ${ARNOLD_VERSION_ARCH_NUM}.${ARNOLD_VERSION_MAJOR_NUM}.${ARNOLD_VERSION_MINOR_NUM}.${ARNOLD_VERSION_FIX})
endif()

function(arnold_compile_osl)
    set(options QUIET VERBOSE INSTALL INSTALL_SOURCES)
    set(oneValueArgs OSLC_FLAGS DESTINATION DESTINATION_SOURCES)
    set(multiValueArgs INCLUDES SOURCES)
    cmake_parse_arguments(arnold_compile_osl "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if (CMAKE_BUILD_TYPE MATCHES Debug)
        set(OSLC_OPT_FLAGS "-d -O0")
    elseif (CMAKE_BUILD_TYPE MATCHES Release)
        set(OSLC_OPT_FLAGS "-O2")
    elseif (CMAKE_BUILD_TYPE MATCHES RelWithDebInfo)
        set(OSLC_OPT_FLAGS "-d -O2")
    else ()
        set(OSLC_OPT_FLAGS "-O2")
    endif ()

    set(OSLC_FLAGS "-I${ARNOLD_OSL_HEADER_DIR}")
    set(OSLC_FLAGS "${OSLC_FLAGS} ${arnold_compile_osl_OSLC_FLAGS}")
    if (${arnold_compile_osl_QUIET})
        set(OSLC_FLAGS "${OSLC_FLAGS} -q")
    endif ()

    if (${arnold_compile_osl_VERBOSE})
        set(OSLC_FLAGS "${OSLC_FLAGS} -v")
    endif ()

    foreach (include ${arnold_compile_osl_INCLUDES})
        set(OSLC_FLAGS "${OSLC_FLAGS} -I${include}")
    endforeach ()

    set(OSLC_FLAGS "${OSLC_FLAGS} ${OSLC_OPT_FLAGS}")
    if (${arnold_compile_osl_VERBOSE})
        message (STATUS "OSL - Arnold compile options : ${OSLC_FLAGS}")
    endif ()

    foreach (source ${arnold_compile_osl_SOURCES})
        # unique name for each target
        string(REPLACE ".osl" ".oso" target_name ${source})
        string(REPLACE "/" "_" target_name ${target_name})
        string(REPLACE "\\" "_" target_name ${target_name})
        set(target_path "${CMAKE_CURRENT_BINARY_DIR}/${target_name}")
        string(REPLACE "." "_" target_name ${target_name})
        set(cmd_args "${OSLC_FLAGS} -o ${target_path} ${source}")
        separate_arguments(cmd_args)        
        add_custom_command(OUTPUT ${target_path}
                           COMMAND ${ARNOLD_OSLC} ${cmd_args}
                           WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
        add_custom_target(${target_name} ALL
                          DEPENDS ${target_path}
                          SOURCES ${source})
        if (${arnold_compile_osl_INSTALL})
            get_filename_component(install_name ${source} NAME)
            # rename the unique files
            string(REPLACE ".osl" ".oso" install_name ${install_name})
            install(FILES ${target_path}
                    DESTINATION ${arnold_compile_osl_DESTINATION}
                    RENAME ${install_name})
        endif ()
        if (${arnold_compile_osl_INSTALL_SOURCES})
            install(FILES ${source} DESTINATION ${arnold_compile_osl_DESTINATION_SOURCES})
        endif ()
    endforeach ()
endfunction()

message(STATUS "Arnold library: ${ARNOLD_LIBRARY}")
message(STATUS "Arnold headers: ${ARNOLD_INCLUDE_DIR}")
message(STATUS "Arnold version: ${ARNOLD_VERSION}")

include(FindPackageHandleStandardArgs)

if (${ARNOLD_VERSION_ARCH_NUM} VERSION_GREATER "4")
    find_package_handle_standard_args(Arnold
        REQUIRED_VARS
        ARNOLD_LIBRARY
        ARNOLD_INCLUDE_DIR
        ARNOLD_OSLC
        ARNOLD_OSL_HEADER_DIR
        VERSION_VAR
        ARNOLD_VERSION)
else ()
    find_package_handle_standard_args(Arnold
        REQUIRED_VARS
        ARNOLD_LIBRARY
        ARNOLD_INCLUDE_DIR
        VERSION_VAR
        ARNOLD_VERSION)
endif ()

cmake_minimum_required(VERSION 3.10)
# set the project name
project(psbuild)

set( PURS_DIR ${CMAKE_CURRENT_LIST_DIR} )
set( BUILD_DIR ${CMAKE_CURRENT_BINARY_DIR} )

# specify the C++ standard
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED True)

set( SPAGO_BUILD_COMMAND_MAKE
  spago build
  -u '--codegen corefn -o output/purs'
  -t './zephyr.bash Main'
  -t 'pscpp output/dce/*/corefn.json'
  )

set( SPAGO_BUILD_COMMAND_CMAKE
  spago build
  -u " --codegen corefn -o output/purs "
  -t " ./zephyr.bash Main "
  -t " pscpp output/dce/*/corefn.json "
  )

execute_process(
  COMMAND ${SPAGO_BUILD_COMMAND_CMAKE}
  WORKING_DIRECTORY ${PURS_DIR}
  )

# Module to lower case >> '.'->'-', lower case
function( modtolc l ret )
  set( r "" )
  foreach( m ${l} )
    string( TOLOWER ${m} v )
    string( REPLACE . - v_ ${v} )
    list( APPEND r ${v_} )
  endforeach()
  set( ${ret} ${r} PARENT_SCOPE )
endfunction()

# Module to underline >> '.'->'_'
function( modtoul l ret )
  set( r "" )
  foreach( m ${l} )
    string( REPLACE . _ v ${m} )
    list( APPEND r ${v} )
  endforeach()
  set( ${ret} ${r} PARENT_SCOPE )
endfunction()

# filter out given files $(1) by Modules $(2) 
function( filtermod fs ms ret)
  set( r "")
  foreach( f ${fs})
    get_filename_component( f_ ${f} NAME_WE )
    foreach( m ${ms})
      if( ${m} STREQUAL ${f_} )
	list( APPEND r ${f} )
	break()
      endif()
    endforeach()
  endforeach()
  set( ${ret} ${r} PARENT_SCOPE)
endfunction()

function( modfrompurs f ret )
  set( re "module[ \t\n\r]+([a-zA-Z0-9\.]+)[ \t\n\r]+where")
  file(STRINGS ${f} mod REGEX ${re} )
  if(${mod} MATCHES ${re})
    set( ${ret} ${CMAKE_MATCH_1} PARENT_SCOPE)
  else()
    set( ${ret} "" PARENT_SCOPE)
  endif()
endfunction()

# filter out given purs files by modules
function( filterpurs fs ms ret)
  set( r "")
  foreach( f ${fs})
    modfrompurs( ${f} mod)
    foreach( m ${ms})
      if( ${m} STREQUAL ${mod} )
	list( APPEND r ${f} )
	break()
      endif()
    endforeach()
  endforeach()
  set( ${ret} ${r} PARENT_SCOPE)
endfunction()

# modules which are truely needed
file( GLOB USED_MOD
  LIST_DIRECTORIES true
  CONFIGURE_DEPENDS
  RELATIVE ${PURS_DIR}/output/dce
  ${PURS_DIR}/output/dce/*
  )

# all ffi sources are in ffi dir 
file( GLOB_RECURSE FFIDIR_SRCS
  LIST_DIRECTORIES false
  CONFIGURE_DEPENDS
  ${PURS_DIR}/ffi/*.cpp
  )
# all ffi sources are in src dir
file( GLOB_RECURSE FFISRC_SRCS
  LIST_DIRECTORIES false
  CONFIGURE_DEPENDS
  ${PURS_DIR}/src/*.cpp
  )
# all purescript sources in the src dir
file(
  GLOB_RECURSE PURS_SRCS
  LIST_DIRECTORIES false
  CONFIGURE_DEPENDS
  ${PURS_DIR}/src/*.purs
  )

modtolc( "${USED_MOD}" USED_MODLC ) # modules lowercase
modtoul( "${USED_MOD}" USED_MODUL ) # modules underlined

# used ffi's
filtermod( "${FFIDIR_SRCS}${FFISRC_SRCS}" "${USED_MODLC}" USED_FFI )
# used purescript srcs 
filterpurs( "${PURS_SRCS}" "${USED_MOD}" USED_PURS ) 

# purescript compiled cpp
set( USED_PSC "")
foreach( m ${USED_MODUL}) 
  list( APPEND USED_PSC ${PURS_DIR}/output/cpp/modules/${m}.cpp )
endforeach()

set(
  USED_CPP
  "${USED_FFI}" "${USED_PSC}"
  ${PURS_DIR}/output/cpp/runtime/purescript.cpp
  )

include_directories(
  ${PURS_DIR}/output/cpp/runtime
  ${PURS_DIR}/output/cpp/modules
  )
add_executable( main "${USED_CPP}")

# create dependency mapping to
# purs files in src from corresponding cpp
set( USED_PSC_SRC "")
foreach( p ${USED_PURS})
  modfrompurs( ${p} mod )
  modtoul( ${mod} modul )
  set( cpp ${PURS_DIR}/output/cpp/modules/${modul}.cpp)
  list( APPEND USED_PSC_SRC ${cpp}) 
  add_custom_command( 
    OUTPUT ${cpp}
    COMMAND ${SPAGO_BUILD_COMMAND_MAKE}
    DEPENDS ${p}
    WORKING_DIRECTORY ${PURS_DIR}
    COMMENT "PURS (${mod}) -> CPP"
    # using VERBATIM will screw up quotes!!!!
    )
endforeach()

add_custom_target(spago DEPENDS ${USED_PSC_SRC} )

add_dependencies( main spago )

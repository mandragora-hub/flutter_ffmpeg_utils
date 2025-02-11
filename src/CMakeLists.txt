# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(ffmpeg_utils_library VERSION 0.0.1 LANGUAGES C)

# SET(PLUGIN_NAME "${PROJECT_NAME}_plugin")

add_library(ffmpeg_utils SHARED
  "ffmpeg_utils.c"
  "common.c"
)

set_target_properties(ffmpeg_utils PROPERTIES
  PUBLIC_HEADER ffmpeg_utils.h
  OUTPUT_NAME "ffmpeg_utils"
)

if(UNIX AND NOT APPLE AND NOT ANDROID) # set(LINUX TRUE)
  find_package(PkgConfig REQUIRED)
  pkg_check_modules(LIBAV REQUIRED IMPORTED_TARGET
      libavdevice
      libavfilter
      libavformat
      libavcodec
      libswresample
      libswscale
      libavutil
  )
  target_link_libraries(ffmpeg_utils PkgConfig::LIBAV)
endif()


target_compile_definitions(ffmpeg_utils PUBLIC DART_SHARED_LIB)

if (ANDROID)

  # Add ffmpeg library
  set(FFMPEG_DIR ${CMAKE_CURRENT_SOURCE_DIR}/.dependecies/android/ffmpeg/${ANDROID_ABI})
  set(AV_LIBRARY 
    ${FFMPEG_DIR}/lib/libavcodec.so
    ${FFMPEG_DIR}/lib/libavdevice.so
    ${FFMPEG_DIR}/lib/libavfilter.so
    ${FFMPEG_DIR}/lib/libavformat.so
    ${FFMPEG_DIR}/lib/libavutil.so
    ${FFMPEG_DIR}/lib/libswresample.so
    ${FFMPEG_DIR}/lib/libswscale.so
  )
  include_directories(${FFMPEG_DIR}/include)


  # Add another android libraries
  find_library( # Sets the name of the path variable.
    log-lib

    # Specifies the name of the NDK library that
    # you want CMake to locate.
    log
  )

  target_link_libraries(ffmpeg_utils ${AV_LIBRARY} ${log-lib})
  # add_compile_definitions(LIBAV_AVAILABLE)


  # Support Android 15 16k page size
  target_link_options(ffmpeg_utils PRIVATE "-Wl,-z,max-page-size=16384")
endif()

cmake_minimum_required(VERSION 3.15)
project(VoiceOcclusion VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded")

# Find required packages
find_package(Lua 5.1 REQUIRED)

# Gmod SDK paths (adjust these to your environment)
set(GMOD_SDK_DIR "" CACHE PATH "Path to gmod-module-base SDK")
set(SOURCE_SDK_DIR "" CACHE PATH "Path to Source SDK 2013")

# Include directories
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${LUA_INCLUDE_DIR}
)

if(GMOD_SDK_DIR)
    include_directories(${GMOD_SDK_DIR}/include)
endif()

# Source files
set(SOURCES
    src/module.cpp
    src/audio_processor.cpp
    src/lua_interface.cpp
)

# Create shared library (module)
add_library(voiceocclusion SHARED ${SOURCES})

# Set output name (without lib prefix on Linux)
set_target_properties(voiceocclusion PROPERTIES
    PREFIX ""
    OUTPUT_NAME "gmcl_voiceocclusion"
)

# Platform-specific settings
if(WIN32)
    # Windows DLL
    set_target_properties(voiceocclusion PROPERTIES
        SUFFIX ".dll"
    )
elseif(UNIX)
    # Linux shared object
    set_target_properties(voiceocclusion PROPERTIES
        SUFFIX ".dll"
    )
endif()

# Link libraries
target_link_libraries(voiceocclusion
    ${LUA_LIBRARIES}
)

# Compiler definitions
target_compile_definitions(voiceocclusion PRIVATE
    GMMODULE
    GMOD_MODULE
    LUA_COMPAT_ALL
)

# Compiler flags
if(MSVC)
    target_compile_options(voiceocclusion PRIVATE
        /W4
        /EHsc
    )
else()
    target_compile_options(voiceocclusion PRIVATE
        -Wall
        -Wextra
    )
endif()

# Install rules
install(TARGETS voiceocclusion
    RUNTIME DESTINATION bin
    LIBRARY DESTINATION lib
)

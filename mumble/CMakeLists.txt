cmake_minimum_required(VERSION 3.15)
project(ImmersiveVoiceChatMumble VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded")

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)

add_library(immersivevoicechat_mumble SHARED src/plugin.cpp)

set_target_properties(immersivevoicechat_mumble PROPERTIES
    PREFIX ""
    OUTPUT_NAME "mumble_immersivevoicechat"
    SUFFIX ".dll"
)

if(MSVC)
    target_compile_options(immersivevoicechat_mumble PRIVATE /W4 /EHsc)
endif()

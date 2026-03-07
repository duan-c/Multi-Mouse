cmake_minimum_required(VERSION 3.20)
project(multi_mouse LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT DEFINED GODOT_CPP_PATH)
    message(FATAL_ERROR "Set GODOT_CPP_PATH to your godot-cpp checkout (e.g. -DGODOT_CPP_PATH=../godot-cpp)")
endif()

add_subdirectory(${GODOT_CPP_PATH} ${CMAKE_BINARY_DIR}/godot-cpp)

add_library(multi_mouse SHARED
    register_types.cpp
    multi_mouse_server.cpp
)

target_include_directories(multi_mouse PRIVATE
    ${GODOT_CPP_PATH}/include
    ${GODOT_CPP_PATH}/include/godot_cpp
)

target_link_libraries(multi_mouse PRIVATE godot-cpp)

target_compile_definitions(multi_mouse PRIVATE
    $<$<CONFIG:Debug>:DEBUG>
)

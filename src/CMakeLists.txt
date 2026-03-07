cmake_minimum_required(VERSION 3.20)
project(multi_mouse LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT DEFINED GODOT_CPP_PATH)
    set(GODOT_CPP_PATH "${CMAKE_SOURCE_DIR}/../extern/godot-cpp" CACHE PATH "Path to godot-cpp checkout" FORCE)
endif()

if(NOT EXISTS "${GODOT_CPP_PATH}/include")
    message(FATAL_ERROR "godot-cpp headers not found in ${GODOT_CPP_PATH}. Did you init the submodule?")
endif()

set(GODOT_CPP_LIB "" CACHE FILEPATH "Path to the prebuilt godot-cpp static library")
if(NOT GODOT_CPP_LIB)
    message(FATAL_ERROR "Set GODOT_CPP_LIB to the built godot-cpp library (e.g. extern/godot-cpp/bin/libgodot-cpp.linux.template_debug.x86_64.a)")
endif()

add_library(multi_mouse SHARED
    register_types.cpp
    multi_mouse_server.cpp
    multi_mouse_backend.cpp
    platform/windows/multi_mouse_backend_windows.cpp
)

target_include_directories(multi_mouse PRIVATE
    ${GODOT_CPP_PATH}/include
    ${GODOT_CPP_PATH}/include/godot_cpp
    ${GODOT_CPP_PATH}/gen/include
    ${GODOT_CPP_PATH}/gen/include/godot_cpp
    ${GODOT_CPP_PATH}/gdextension
)

target_link_libraries(multi_mouse PRIVATE ${GODOT_CPP_LIB})

if(WIN32)
    target_link_libraries(multi_mouse PRIVATE user32)
endif()

if(MSVC)
    target_compile_definitions(multi_mouse PRIVATE TYPED_METHOD_BIND NOMINMAX)
    set_property(TARGET multi_mouse PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
endif()

install(TARGETS multi_mouse DESTINATION ${CMAKE_SOURCE_DIR}/../addons/multi_mouse/bin)

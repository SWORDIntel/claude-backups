cmake_minimum_required(VERSION 3.10)
project(test_project C)

set(CMAKE_C_STANDARD 11)

set(CMAKE_C_FLAGS "${-O3 -DNDEBUG}")

add_executable(test_project ${SOURCES})
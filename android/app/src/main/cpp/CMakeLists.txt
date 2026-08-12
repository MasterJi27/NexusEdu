cmake_minimum_required(VERSION 3.18.1)
project("nx_math_solver")

add_library(nx_math_solver SHARED nx_math_solver.cpp)

target_compile_options(nx_math_solver PRIVATE -O3 -ffast-math)
target_link_libraries(nx_math_solver log m)

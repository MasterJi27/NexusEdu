cmake_minimum_required(VERSION 3.14)
project(nexus_engine CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(nexus_engine SHARED
    math_engine.cpp
    quiz_engine.cpp
    analytics_engine.cpp
    question_bank.cpp
    study_planner.cpp
    grading_engine.cpp
    indian_education.cpp
    main_interface.cpp
)

target_compile_options(nexus_engine PRIVATE -O3 -Wall -Wextra)

include_directories(${CMAKE_SOURCE_DIR})

enable_testing()
add_executable(nexus_tests tests/test_engine.cpp)
target_link_libraries(nexus_tests nexus_engine)
add_test(NAME nexus_tests COMMAND nexus_tests)

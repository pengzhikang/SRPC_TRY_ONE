# CMake 最低版本号要求
cmake_minimum_required (VERSION 3.17)

#set(CMAKE_BUILD_TYPE "Release")
# 项目信息
project (srpc_try_one)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_FLAGS "-O2 -Wall -std=c++11")
set(CMAKE_CXX_FLAGS_RELEASE "$ENV{CMAKE_CXX_FLAGS}")


#<-------------------------------------------------->
#设置c++的版本并添加多线程的使用
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -pthread")
#设置输出文件的路径
set(EXECUTABLE_OUTPUT_PATH ${PROJECT_BINARY_DIR}/release)

include_directories("${CMAKE_CURRENT_SOURCE_DIR}/include")
include_directories("/usr/local/include")
link_libraries("/usr/local/lib")


# 查找当前目录的所有源文件
OPTION (Build_Client             "Build Client"                           ON)
if(Build_Client)
    set(REQUIRE_CPP 
        src/client.cc src/example.pb.cc)
else()
    set(REQUIRE_CPP 
        src/server.cc src/example.pb.cc)
endif()
#指定生成目标
add_executable(test ${REQUIRE_CPP})

#添加链接库
target_link_libraries(test srpc)
target_link_libraries(test protobuf)
target_link_libraries(test workflow)
if (WIN32)
	target_compile_definitions(test PRIVATE -DWIN32_LEAN_AND_MEAN -D_SILENCE_EXPERIMENTAL_FILESYSTEM_DEPRECATION_WARNING)
else ()
	target_link_libraries(test stdc++fs)
endif ()

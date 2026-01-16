cmake_minimum_required(VERSION 3.18.1)
project("flyer_chat_native")

# 设置 C++ 标准
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

#include_directories(include)
#include_directories(${CMAKE_SOURCE_DIR}/../llama.cpp/include)
# ==============================
# Vosk JNI Bridge (原有功能)
# ==============================
add_library(vosk_jni_bridge SHARED
        src/main/cpp/vosk_jni_bridge.cpp
)

find_library(log-lib log)

# 链接库 - Vosk 使用动态加载
target_link_libraries(vosk_jni_bridge
        ${log-lib}
        dl  # 用于动态加载 libvosk.so
)

# ==============================
# Llama JNI Bridge (新增)
# ==============================
# 设置 llama.cpp 头文件路径（相对于 CMakeLists.txt）

set(LLAMA_CPP_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../llama.cpp")
set(LLAMA_INCLUDE_DIR "${LLAMA_CPP_ROOT}/include")
set(GGML_INCLUDE_DIR "${LLAMA_CPP_ROOT}/ggml/include")  # ← 新增 ggml 路径


get_filename_component(ANDROID_DIR "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)
set(LLAMA_INCLUDE_DIR "${ANDROID_DIR}/llama.cpp/include")

# 检查头文件是否存在
if(EXISTS "${LLAMA_INCLUDE_DIR}/llama.h")
    message(STATUS "找到 llama.h 在: ${LLAMA_INCLUDE_DIR}")
    message(STATUS "✅ 找到 ggml.h 在: ${GGML_INCLUDE_DIR}")

    # 创建 llama_jni 库
    add_library(llama_jni SHARED
            src/main/cpp/llama_jni.cpp
    )
#    target_link_directories(llama_jni PRIVATE ${CMAKE_SOURCE_DIR}/src/main/jniLibs/${ANDROID_ABI})

    # 包含头文件目录
    target_include_directories(llama_jni PRIVATE
            ${LLAMA_INCLUDE_DIR}
            ${GGML_INCLUDE_DIR}
    )

    # 查找系统库
    find_library(log-lib log)
    find_library(android-lib android)

    # 链接 libllama.so（位于 jniLibs/arm64-v8a/）
    # 注意：CMake 会自动从 jniLibs 目录链接预编译的 .so 文件
    # 但我们需要显式链接它
    get_filename_component(JNI_LIBS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src/main/jniLibs" ABSOLUTE)

    # 根据当前架构设置库路径
#    set(LLAMA_LIB_PATH "${JNI_LIBS_DIR}/arm64-v8a/libllama.so")

    if(ANDROID_ABI STREQUAL "arm64-v8a")
        set(LLAMA_LIB_PATH "${JNI_LIBS_DIR}/arm64-v8a/libllama.so")
    elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
        set(LLAMA_LIB_PATH "${JNI_LIBS_DIR}/armeabi-v7a/libllama.so")
    elseif(ANDROID_ABI STREQUAL "x86")
        set(LLAMA_LIB_PATH "${JNI_LIBS_DIR}/x86/libllama.so")
    elseif(ANDROID_ABI STREQUAL "x86_64")
        set(LLAMA_LIB_PATH "${JNI_LIBS_DIR}/x86_64/libllama.so")
    endif()

    # 如果找到了预编译的 libllama.so，链接它
    if(EXISTS "${LLAMA_LIB_PATH}")
        message(STATUS "找到 libllama.so 在: ${LLAMA_LIB_PATH}")

        link_directories("${JNI_LIBS_DIR}/${ANDROID_ABI}")

        target_link_libraries(llama_jni
                ${log-lib}
                ${android-lib}
                atomic
                m
                "${LLAMA_LIB_PATH}"
        )
    else()
        message(FATAL_ERROR "未找到预编译的 libllama.so，请检查路径：${LLAMA_LIB_PATH}")
    endif()

    # 编译选项
    target_compile_options(llama_jni PRIVATE
            -Wall
            -Wextra
    )

else()
    message(FATAL_ERROR "❌ 缺失头文件！\n  llama.h: ${LLAMA_INCLUDE_DIR}/llama.h\n  ggml.h: ${GGML_INCLUDE_DIR}/ggml.h")
endif()

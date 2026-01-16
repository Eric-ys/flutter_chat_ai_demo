# Vosk JNI 桥接层

## 概述

由于 vosk-android AAR 中的原生库（libvosk.so）只包含 C 函数，没有 JNI 绑定，我们需要创建一个 JNI 桥接层来调用这些 C 函数。

## 文件说明

- `vosk_jni_bridge.cpp` - JNI 桥接层实现，将 Java 调用转换为 C 函数调用
- `CMakeLists.txt` - CMake 构建配置

## 编译要求

- Android NDK
- CMake 3.18.1 或更高版本
- C++11 支持

## 链接说明

桥接库会链接到 AAR 中的 `libvosk.so`。AAR 中的原生库会在打包时自动包含到 APK 中。

## 注意事项

- JNI 函数名必须匹配 Java 方法名（使用下划线代替点号）
- 例如：`Java_org_vosk_LibVosk_vosk_1model_1new` 对应 `org.vosk.LibVosk.vosk_model_new`
- 函数签名必须完全匹配


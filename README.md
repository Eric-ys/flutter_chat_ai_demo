# Flyer Chat - 本地大语言模型集成

一个基于 Flutter 的聊天应用，集成了本地大语言模型（LLM）推理能力，支持在 Android 设备上离线运行 Qwen2.5-3B 模型。
基于 https://github.com/flyerhq/flutter_chat_ui 实现，该项目仅作为个人学习demo使用

## 📋 目录

- [功能特性](#功能特性)
- [架构概览](#架构概览)
- [快速开始](#快速开始)
    - [前置要求](#前置要求)
    - [安装步骤](#安装步骤)
- [模型部署](#模型部署)
    - [为什么使用内部私有目录？](#为什么使用内部私有目录)
    - [部署步骤](#部署步骤)
    - [手动部署（可选）](#手动部署可选)
- [技术细节](#技术细节)
- [故障排除](#故障排除)
    - [模型加载失败](#模型加载失败)
    - [权限问题](#权限问题)
    - [模型文件不存在](#模型文件不存在)
    - [libllama.so 加载失败](#libllamaso-加载失败)
- [项目结构](#项目结构)
- [相关文档](#相关文档)
- [最佳实践](#最佳实践)
- [已知限制](#已知限制)

## ✨ 功能特性

- ✅ **本地 LLM 推理**：使用 llama.cpp 在 Android 设备上本地运行 Qwen2.5-3B 模型
- ✅ **流式输出**：实时流式显示 AI 回复，提供流畅的用户体验
- ✅ **对话历史管理**：自动维护对话上下文，支持多轮对话
- ✅ **Qwen2.5 格式支持**：自动将聊天历史转换为 Qwen2.5 对话模板
- ✅ **停止生成**：支持在生成过程中停止 AI 回复
- ✅ **富文本渲染**：使用 Markdown 渲染 AI 回复，支持代码块、链接等
- ✅ **无网络依赖**：完全离线运行，保护用户隐私

## 🏗️ 架构概览

本项目采用多层架构，实现 Flutter 到原生 C++ 的无缝集成：

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter UI Layer                          │
│  (lib/local.dart, lib/inference/qwen_chat_helper.dart)      │
└──────────────────────┬──────────────────────────────────────┘
                       │ MethodChannel / EventChannel
┌──────────────────────▼──────────────────────────────────────┐
│                   Kotlin Bridge Layer                        │
│  (MainActivity.kt, LlamaInference.kt)                       │
└──────────────────────┬──────────────────────────────────────┘
                       │ JNI
┌──────────────────────▼──────────────────────────────────────┐
│                    JNI C++ Layer                             │
│  (android/app/src/main/cpp/llama_jni.cpp)                   │
└──────────────────────┬──────────────────────────────────────┘
                       │ Native API
┌──────────────────────▼──────────────────────────────────────┐
│                  llama.cpp Library                           │
│  (libllama.so - 已编译的 Android 版本)                       │
└─────────────────────────────────────────────────────────────┘
```

### 数据流

1. **用户发送消息** → Flutter UI 层
2. **构建 Qwen Prompt** → `QwenChatHelper._buildQwenPrompt()`
3. **调用推理接口** → `LlamaInference.generateStream()`
4. **MethodChannel 通信** → Kotlin 层接收请求
5. **JNI 调用** → C++ 层执行推理
6. **流式返回 Token** → EventChannel 逐字符返回
7. **UI 实时更新** → `SimpleStreamManager` 管理流式状态
8. **渲染显示** → `NativeChatTextStreamMessage` 显示富文本

## 🚀 快速开始

### 前置要求

- Flutter SDK 3.9.2+
- Android SDK (API 21+)
- Android NDK (用于编译原生代码)
- CMake 3.10+
- 已编译的 `libllama.so` (位于 `android/app/src/main/jniLibs/arm64-v8a/`)
- Qwen2.5-3B GGUF 模型文件

### 安装步骤

1. **克隆项目并安装依赖**

```bash
cd examples/flyer_chat
flutter pub get
```

2. **编译 llama.cpp 库**

本项目需要预编译的 `libllama.so` 库。按照以下标准流程编译：

#### 前提条件

- **操作系统**：macOS / Linux
- **NDK 路径**：`/Users/admin/Library/Android/sdk/ndk/25.1.8937393`（或您的 NDK 路径）
- **CMake** ≥ 3.21
- **目标架构**：arm64-v8a

#### 编译步骤

**步骤一：克隆 llama.cpp 仓库**

```bash
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp
```

**步骤二：创建构建目录并配置 CMake**

```bash
# 创建构建目录
mkdir build-android-arm64
cd build-android-arm64

# 设置 NDK 路径（根据您的实际路径修改）
export ANDROID_NDK=/Users/admin/Library/Android/sdk/ndk/25.1.8937393

# 运行 CMake 配置（生成 .so 动态库）
cmake .. \
  -DCMAKE_SYSTEM_NAME=Android \
  -DCMAKE_SYSTEM_VERSION=24 \
  -DCMAKE_ANDROID_ARCH_ABI=arm64-v8a \
  -DCMAKE_ANDROID_NDK=$ANDROID_NDK \
  -DCMAKE_ANDROID_STL_TYPE=c++_shared \
  -DLLAMA_NATIVE=OFF \
  -DLLAMA_STATIC=OFF \
  -DBUILD_SHARED_LIBS=ON \
  -DLLAMA_BUILD_TESTS=OFF \
  -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_SERVER=OFF \
  -DLLAMA_BUILD_CLI=OFF \
  -DCMAKE_BUILD_TYPE=Release
```

**参数说明**：
- `-DCMAKE_SYSTEM_NAME=Android`：指定目标系统为 Android
- `-DCMAKE_SYSTEM_VERSION=24`：Android API 级别（建议 24+）
- `-DCMAKE_ANDROID_ARCH_ABI=arm64-v8a`：目标架构
- `-DCMAKE_ANDROID_STL_TYPE=c++_shared`：使用共享 C++ 标准库
- `-DBUILD_SHARED_LIBS=ON`：生成动态库（.so）
- `-DLLAMA_BUILD_CLI=OFF`：不编译 CLI 工具（仅生成 libllama.so）

**步骤三：编译生成 .so 文件**

```bash
# 编译（使用所有可用 CPU 核心）
cmake --build . -j$(nproc 2>/dev/null || sysctl -n hw.ncpu)
```

编译成功后，在 `build-android-arm64/` 目录下会生成：
- `libllama.so` ← **核心推理库（必须）**

**步骤四：复制到项目**

```bash
# 假设您在 llama.cpp 的 build-android-arm64 目录下
# 根据您的项目路径调整以下路径

# 创建 jniLibs 目录（如果不存在）
mkdir -p /path/to/flutter_chat_ui/examples/flyer_chat/android/app/src/main/jniLibs/arm64-v8a

# 复制 libllama.so 到项目
cp libllama.so /path/to/flutter_chat_ui/examples/flyer_chat/android/app/src/main/jniLibs/arm64-v8a/

# 或者，如果您在项目根目录下编译，可以使用相对路径：
# cp libllama.so ../../examples/flyer_chat/android/app/src/main/jniLibs/arm64-v8a/

# 验证库文件
ls -lh /path/to/flutter_chat_ui/examples/flyer_chat/android/app/src/main/jniLibs/arm64-v8a/libllama.so
file /path/to/flutter_chat_ui/examples/flyer_chat/android/app/src/main/jniLibs/arm64-v8a/libllama.so
```

**验证结果**：
- 文件应存在且大小约 50-100MB
- 架构应为 `arm64-v8a`（使用 `file` 命令验证）

**快速验证命令**：
```bash
# 检查文件是否存在
ls -lh examples/flyer_chat/android/app/src/main/jniLibs/arm64-v8a/libllama.so

# 检查架构（macOS）
file examples/flyer_chat/android/app/src/main/jniLibs/arm64-v8a/libllama.so

# 检查架构（Linux）
readelf -h examples/flyer_chat/android/app/src/main/jniLibs/arm64-v8a/libllama.so | grep Machine
```

**注意**：
- 如果编译失败，请检查 NDK 路径是否正确
- 确保 CMake 版本 ≥ 3.21
- 确保 NDK 版本 ≥ 25.1.8937393（或兼容版本）
- 参考 [llama.cpp Android 构建文档](https://github.com/ggerganov/llama.cpp/blob/master/docs/android.md) 获取更多帮助

3. **准备模型文件**

下载 Qwen2.5-3B GGUF 模型文件（推荐 Q4_K_M 量化版本）：
- 模型来源：[Hugging Face - Qwen2.5-3B-Instruct-GGUF](https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF)
- 推荐文件：`qwen2.5-3b-instruct-q4_k_m.gguf`
- 文件大小：约 2.1GB

将模型文件保存到本地路径（默认：`/Users/admin/flutter_chat_ui/qwen2_5_3b.Q4_K_M.gguf`）

4. **部署模型文件**

将模型文件部署到 Android 设备的内部私有目录：

```bash
# 确保模型文件在本地路径
# 默认路径: /Users/admin/flutter_chat_ui/qwen2_5_3b.Q4_K_M.gguf

# 运行部署脚本
chmod +x scripts/deploy_model_to_internal.sh
./scripts/deploy_model_to_internal.sh
```

**部署脚本说明**：
- 自动检查 adb 连接和设备状态
- 检查应用是否已安装
- 创建内部目录结构
- 复制模型文件并设置权限
- 验证文件完整性

5. **运行应用**

```bash
flutter run
```

应用启动时会自动：
- 检查模型文件是否存在
- 加载 llama.cpp 库
- 初始化模型（首次加载可能需要几秒钟）

## 📦 模型部署

### 为什么使用内部私有目录？

Android 的 `/sdcard` 路径是 FUSE 文件系统，不支持 Direct I/O，会导致 `llama.cpp` 加载模型失败。使用内部私有目录（`/data/data/包名/app_flutter/`）可以：

- ✅ 支持 Direct I/O 和内存映射
- ✅ 无需存储权限
- ✅ 文件不会被系统自动清理
- ✅ 性能更好

### 部署步骤

1. **准备模型文件**

确保模型文件位于本地路径（默认：`/Users/admin/flutter_chat_ui/qwen2_5_3b.Q4_K_M.gguf`）

2. **连接 Android 设备**

```bash
adb devices
```

3. **运行部署脚本**

```bash
cd examples/flyer_chat
chmod +x scripts/deploy_model_to_internal.sh
./scripts/deploy_model_to_internal.sh
```

脚本会自动：
- 检查 adb 和设备连接
- 检查应用是否已安装
- 创建内部目录结构 (`/data/data/flyer.chat.flyer_chat/app_flutter/models/`)
- 复制模型文件
- 设置文件权限 (644)
- 验证文件完整性

4. **验证部署**

运行应用后，检查日志：

```
✅ 模型文件已存在: /data/user/0/flyer.chat.flyer_chat/app_flutter/models/qwen2_5_3b.Q4_K_M.gguf
✅ Llama 模型加载成功
```

### 手动部署（可选）

如果脚本无法使用，可以手动部署：

```bash
# 1. 创建目录
adb shell "run-as flyer.chat.flyer_chat mkdir -p /data/data/flyer.chat.flyer_chat/app_flutter/models"

# 2. 推送文件到临时位置
adb push qwen2_5_3b.Q4_K_M.gguf /sdcard/tmp_model.gguf

# 3. 复制到内部目录
adb shell "run-as flyer.chat.flyer_chat cp /sdcard/tmp_model.gguf /data/data/flyer.chat.flyer_chat/app_flutter/models/qwen2_5_3b.Q4_K_M.gguf"

# 4. 设置权限
adb shell "run-as flyer.chat.flyer_chat chmod 644 /data/data/flyer.chat.flyer_chat/app_flutter/models/qwen2_5_3b.Q4_K_M.gguf"

# 5. 清理临时文件
adb shell rm /sdcard/tmp_model.gguf
```

## 🔧 技术细节

### 模型配置

- **模型格式**：GGUF (Q4_K_M 量化)
- **上下文长度**：2048 tokens
- **线程数**：4 线程
- **采样策略**：Greedy sampling
- **最大生成 tokens**：256

### 架构实现

本项目采用多层架构实现 Flutter 到原生 C++ 的集成：

- **Flutter 层**：通过 MethodChannel 和 EventChannel 与原生层通信
- **Kotlin 桥接层**：处理平台通道消息，管理 JNI 调用
- **JNI C++ 层**：直接调用 llama.cpp API 进行模型推理
- **流式输出**：C++ 层通过 JNI 回调逐 token 返回，Kotlin 层通过 EventChannel 推送到 Flutter，Dart 层使用 Stream 接收并实时更新 UI

### 关键技术点

- **JNI 跨线程通信**：使用全局引用和 `AttachCurrentThread` 实现 C++ 后台线程到 Java/Kotlin 的回调
- **流式状态管理**：通过 `ChangeNotifier` 和 `AnimatedBuilder` 实现响应式 UI 更新
- **KV Cache 管理**：每次生成前清空 KV Cache，确保对话上下文一致性
- **文件系统优化**：模型文件存储在应用内部私有目录，支持 Direct I/O 和内存映射
- **异步处理**：所有耗时操作（模型加载、推理、文件 I/O）都在后台线程执行

## 🐛 故障排除

### 模型加载失败

**错误信息**：`E/LlamaJNI: read error: Invalid argument`

**解决方案**：
1. 确保模型文件在内部私有目录（不是 `/sdcard`）
2. 检查文件权限（应该是 644）
3. 验证文件完整性（文件大小是否正确）

### 权限问题

**错误信息**：`run-as: exec failed for test: Permission denied`

**解决方案**：
1. 确保应用是 debug 版本
2. 确保应用至少运行过一次（创建 `app_flutter` 目录）
3. 如果仍有问题，可能需要 root 权限

### 模型文件不存在

**错误信息**：模型文件路径不存在

**解决方案**：
1. 运行部署脚本：`./scripts/deploy_model_to_internal.sh`
2. 手动检查文件是否存在：`adb shell "run-as flyer.chat.flyer_chat ls -l /data/data/flyer.chat.flyer_chat/app_flutter/models/"`
3. 确保应用至少运行过一次（创建 `app_flutter` 目录）

### libllama.so 加载失败

**错误信息**：`java.lang.UnsatisfiedLinkError: dlopen failed: library "libllama.so" not found`

**解决方案**：
1. 检查 `libllama.so` 是否存在于 `android/app/src/main/jniLibs/arm64-v8a/`
2. 验证库文件架构：`file android/app/src/main/jniLibs/arm64-v8a/libllama.so`（应该是 `arm64-v8a`）
3. 检查 `build.gradle.kts` 中的 `abiFilters` 是否包含 `arm64-v8a`
4. 清理并重新构建：`flutter clean && flutter build apk`

## 📁 项目结构

```
examples/flyer_chat/
├── android/
│   └── app/
│       ├── src/
│       │   └── main/
│       │       ├── cpp/
│       │       │   ├── llama_jni.cpp          # JNI C++ 实现
│       │       │   └── CMakeLists.txt         # CMake 配置
│       │       ├── kotlin/
│       │       │   └── flyer/chat/flyer_chat/
│       │       │       ├── MainActivity.kt     # MethodChannel/EventChannel 注册
│       │       │       └── LlamaInference.kt    # Native 方法声明
│       │       └── jniLibs/
│       │           └── arm64-v8a/
│       │               └── libllama.so         # llama.cpp 编译库
│       └── build.gradle.kts                    # Gradle 配置（CMake 集成）
├── lib/
│   ├── inference/
│   │   ├── llama_inference.dart               # Dart 推理接口
│   │   └── qwen_chat_helper.dart               # Qwen2.5 对话助手
│   ├── local.dart                              # 主聊天 UI
│   └── simple_stream_manager.dart              # 流式状态管理
├── scripts/
│   ├── deploy_model_to_internal.sh             # 模型部署脚本
│   └── LLAMA_MODEL_DEPLOYMENT.md               # 部署文档
└── README.md                                    # 本文档
```

## 📚 相关文档

- [模型部署详细说明](scripts/LLAMA_MODEL_DEPLOYMENT.md) - 详细的模型部署步骤和原理说明
- [Qwen 使用示例](lib/inference/QWEN_USAGE_EXAMPLE.md) - Qwen2.5 集成示例代码
- [Llama 使用指南](LLAMA_USAGE.md) - Llama 推理 API 使用指南

## 🎯 最佳实践

1. **模型加载时机**：在应用启动时或首次使用前加载，避免用户等待
2. **错误处理**：所有异步操作都应包含错误处理，向用户显示友好提示
3. **资源管理**：应用退出时调用 `unloadModel()` 释放资源
4. **内存监控**：监控应用内存使用，避免 OOM
5. **性能测试**：在不同设备上测试生成速度，优化参数

## 🚧 已知限制

1. **架构支持**：当前仅支持 `arm64-v8a`，其他架构需要重新编译 `libllama.so`
2. **模型大小**：Qwen2.5-3B 模型约 2.1GB，需要足够的存储空间
3. **生成速度**：取决于设备性能，低端设备可能较慢
4. **上下文长度**：当前限制为 2048 tokens，超出部分会被截断
5. **平台支持**：仅支持 Android，iOS 需要额外配置

## 🔗 相关链接

- [llama.cpp 官方文档](https://github.com/ggerganov/llama.cpp)
- [Qwen2.5 模型](https://huggingface.co/Qwen/Qwen2.5-3B-Instruct)
- [Flutter 平台通道文档](https://docs.flutter.dev/development/platform-integration/platform-channels)

---

**注意**：本项目仅支持 Android 平台（arm64-v8a）。iOS 和其他平台的支持需要额外的配置和编译工作。

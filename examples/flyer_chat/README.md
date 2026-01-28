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
- [使用说明](#使用说明)
  - [基本使用](#基本使用)
  - [API 使用](#api-使用)
  - [Qwen2.5 对话助手](#qwen25-对话助手)
- [技术细节](#技术细节)
  - [模型配置](#模型配置)
  - [JNI 实现](#jni-实现)
  - [流式输出实现详解](#流式输出实现详解)
  - [KV Cache 管理](#kv-cache-管理)
  - [文件系统配置](#文件系统配置)
  - [编译配置](#编译配置)
- [故障排除](#故障排除)
  - [模型加载失败](#模型加载失败)
  - [应用冻结](#应用冻结)
  - [流式输出不显示](#流式输出不显示)
  - [KV Cache 错误](#kv-cache-错误)
  - [权限问题](#权限问题)
  - [模型文件不存在](#模型文件不存在)
  - [libllama.so 加载失败](#libllamaso-加载失败)
  - [流式输出不工作](#流式输出不工作)
  - [JNI 回调失败](#jni-回调失败)
- [项目结构](#项目结构)
- [相关文档](#相关文档)
- [技术深度解析](#技术深度解析)
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

## 📖 使用说明

### 基本使用

1. **启动应用**：应用启动时会自动检查模型文件并加载模型
2. **发送消息**：在输入框中输入消息，点击发送按钮
3. **查看回复**：AI 会实时流式输出回复，支持 Markdown 格式
4. **停止生成**：在生成过程中，发送按钮会变为停止按钮，点击可停止生成

### API 使用

#### 加载模型

```dart
import 'package:flyer_chat/inference/llama_inference.dart';

// 使用默认路径加载模型
bool loaded = await LlamaInference.loadModel();

// 或指定自定义路径
bool loaded = await LlamaInference.loadModel(
  modelPath: '/custom/path/to/model.gguf'
);
```

#### 生成回复（同步）

```dart
String response = await LlamaInference.generate("你好！");
print(response);
```

#### 流式生成回复

```dart
Stream<String> stream = LlamaInference.generateStream("你好！");

stream.listen(
  (token) {
    print(token); // 逐个字符输出
  },
  onDone: () {
    print("生成完成");
  },
  onError: (error) {
    print("错误: $error");
  },
);
```

#### 停止生成

```dart
await LlamaInference.stopGeneration();
```

#### 卸载模型

```dart
await LlamaInference.unloadModel();
```

### Qwen2.5 对话助手

使用 `QwenChatHelper` 可以自动处理对话历史和格式转换：

```dart
import 'package:flyer_chat/inference/qwen_chat_helper.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

// 从聊天历史生成回复
List<Message> messages = [...]; // 聊天历史
String currentUserId = "user123";

String response = await QwenChatHelper.generateResponse(
  messages,
  currentUserId,
);

// 流式生成回复
StreamSubscription<String>? subscription = 
  await QwenChatHelper.generateAndStreamResponse(
    messages: messages,
    currentUserId: currentUserId,
    chatController: chatController,
    streamManager: streamManager,
    onStreamingStateChanged: (isStreaming, subscription) {
      // 处理流式状态变化
    },
    onDone: () {
      print("生成完成");
    },
    onError: (error) {
      print("错误: $error");
    },
  );
```

## 🔧 技术细节

### 模型配置

- **模型格式**：GGUF (Q4_K_M 量化)
- **上下文长度**：2048 tokens
- **线程数**：4 线程
- **采样策略**：Greedy sampling
- **最大生成 tokens**：256

### JNI 实现

#### 核心函数

- `loadModel(String modelPath)`: 加载模型
- `generate(String prompt)`: 同步生成
- `generateStream(String prompt)`: 流式生成
- `stopGeneration()`: 停止生成
- `unloadModel()`: 卸载模型

#### JNI 回调机制详解

本项目使用 JNI 全局引用和回调接口实现 C++ 后台线程到 Java/Kotlin 的跨线程通信：

**1. 初始化回调（`initStreamCallback`）**

```cpp
// 在 C++ 层保存 Java 回调对象的全局引用
Java_flyer_chat_flyer_1chat_LlamaInference_initStreamCallback(
    JNIEnv *env, jclass clazz, jobject callback
) {
    // 1. 清理旧的全局引用（避免内存泄漏）
    if (g_callback_obj) {
        env->DeleteGlobalRef(g_callback_obj);
    }
    
    // 2. 创建新的全局引用（跨线程使用）
    g_callback_obj = env->NewGlobalRef(callback);
    
    // 3. 获取回调类的全局引用
    jclass callback_class = env->GetObjectClass(callback);
    g_callback_class = (jclass)env->NewGlobalRef(callback_class);
    
    // 4. 获取 onToken 方法的 ID
    g_callback_method = env->GetMethodID(callback_class, "onToken", "(Ljava/lang/String;)V");
    
    // 5. 保存 JavaVM 指针（用于在后台线程获取 JNIEnv）
    env->GetJavaVM(&g_jvm);
}
```

**2. 发送 Token（`send_token_to_java`）**

```cpp
// 在 C++ 后台线程中调用 Java 回调方法
void send_token_to_java(const char* token) {
    // 1. 从 JavaVM 获取当前线程的 JNIEnv
    JNIEnv* env;
    int status = g_jvm->AttachCurrentThread(&env, nullptr);
    
    // 2. 将 C 字符串转换为 Java String
    jstring jtoken = env->NewStringUTF(token);
    
    // 3. 调用 Java 回调方法
    env->CallVoidMethod(g_callback_obj, g_callback_method, jtoken);
    
    // 4. 释放局部引用
    env->DeleteLocalRef(jtoken);
}
```

**3. Kotlin 层实现**

```kotlin
// 定义回调接口
interface StreamCallback {
    fun onToken(token: String)
}

// 在 MainActivity 中实现回调
val callback = object : StreamCallback {
    override fun onToken(token: String) {
        // 在主线程中发送 token 到 EventChannel
        runOnUiThread {
            llamaEventSink?.success(token)
        }
    }
}

// 初始化回调
LlamaInference.initStreamCallback(callback)
```

**关键点**：
- **全局引用**：`jobject` 局部引用在函数返回后失效，必须使用 `NewGlobalRef` 创建全局引用
- **线程安全**：C++ 后台线程需要 `AttachCurrentThread` 获取 `JNIEnv`
- **主线程调用**：`EventChannel` 的 `success()` 必须在主线程调用，使用 `runOnUiThread`

### 流式输出实现详解

流式输出的完整数据流：

```
┌─────────────────────────────────────────────────────────────┐
│ 1. C++ 层（llama_jni.cpp）                                   │
│    - 在生成循环中，每生成一个 token                          │
│    - 调用 send_token_to_java(token)                         │
└──────────────────────┬──────────────────────────────────────┘
                       │ JNI CallVoidMethod
┌──────────────────────▼──────────────────────────────────────┐
│ 2. Kotlin 层（MainActivity.kt）                              │
│    - StreamCallback.onToken(token) 被调用                   │
│    - runOnUiThread { llamaEventSink?.success(token) }       │
└──────────────────────┬──────────────────────────────────────┘
                       │ EventChannel
┌──────────────────────▼──────────────────────────────────────┐
│ 3. Dart 层（llama_inference.dart）                           │
│    - EventChannel.receiveBroadcastStream()                   │
│    - stream.listen((token) { ... })                         │
└──────────────────────┬──────────────────────────────────────┘
                       │ StreamSubscription
┌──────────────────────▼──────────────────────────────────────┐
│ 4. 业务层（qwen_chat_helper.dart）                           │
│    - 累积 token: accumulatedText += token                    │
│    - 实时过滤: _checkAndRemoveEndMarker()                    │
│    - 更新状态: streamManager.updateStreamText()              │
└──────────────────────┬──────────────────────────────────────┘
                       │ notifyListeners()
┌──────────────────────▼──────────────────────────────────────┐
│ 5. UI 层（local.dart）                                       │
│    - AnimatedBuilder(animation: _streamManager)             │
│    - NativeChatTextStreamMessage 重建                        │
│    - GptMarkdown 渲染富文本                                  │
└─────────────────────────────────────────────────────────────┘
```

**关键组件**：

1. **SimpleStreamManager**：管理流式状态
   - `updateStreamText()`: 更新累积文本
   - `notifyListeners()`: 触发 UI 重建
   - `completeStream()`: 完成流式输出，转换为普通消息

2. **AnimatedBuilder**：监听状态变化
   ```dart
   AnimatedBuilder(
     animation: _streamManager,
     builder: (context, _) {
       final streamState = _streamManager.getState(message.streamId);
       return NativeChatTextStreamMessage(streamState: streamState);
     },
   )
   ```

3. **实时过滤**：在流式输出过程中检测并移除：
   - `<|im_end|>` 标记（完整或部分形式）
   - 系统提示词回显
   - 其他不需要的内容

### KV Cache 管理

每次生成前会清空 KV Cache，确保对话上下文的一致性：

```cpp
// 清空序列 0 的 KV Cache
llama_memory_seq_rm(llama_get_memory(g_ctx), 0, -1, -1);
```

### 文件系统配置

在 `llama_jni.cpp` 中配置模型加载参数：

```cpp
struct llama_model_params model_params = llama_model_default_params();
model_params.use_mmap = true;        // 启用内存映射（Android 内部目录支持）
model_params.use_direct_io = false;   // 禁用 Direct I/O（避免 FUSE 文件系统错误）
model_params.use_mlock = false;       // 禁用内存锁定（Android 上通常不需要）
model_params.no_alloc = false;        // 允许自动分配内存
```

**为什么使用内部私有目录？**

- **FUSE 文件系统限制**：`/sdcard` 是 FUSE 文件系统，不支持 Direct I/O，会导致 `read error: Invalid argument`
- **性能优势**：内部目录位于真实文件系统，支持内存映射，性能更好
- **权限优势**：无需存储权限，文件不会被系统自动清理
- **安全性**：应用私有目录，其他应用无法访问

### 编译配置

#### Gradle 配置（`android/app/build.gradle.kts`）

```kotlin
android {
    defaultConfig {
        // 配置 NDK ABI 过滤器
        ndk {
            abiFilters.clear()
            abiFilters += listOf("arm64-v8a")  // 当前仅支持 arm64-v8a
        }
        
        // 配置 CMake
        externalNativeBuild {
            cmake {
                cppFlags += listOf("-std=c++17")
                arguments += "-DANDROID_STL=c++_shared"
                abiFilters.clear()
                abiFilters.add("arm64-v8a")
            }
        }
    }
    
    // 配置外部原生构建
    externalNativeBuild {
        cmake {
            path = file("CMakeLists.txt")
            version = "3.22.1"
        }
    }
    
    // 指定 jniLibs 目录
    sourceSets {
        named("main") {
            jniLibs.srcDir("src/main/jniLibs")
        }
    }
}
```

#### CMake 配置（`android/app/src/main/cpp/CMakeLists.txt`）

```cmake
# 设置 C++ 标准
set(CMAKE_CXX_STANDARD 17)

# 创建 llama_jni 共享库
add_library(llama_jni SHARED llama_jni.cpp)

# 包含头文件目录
target_include_directories(llama_jni PRIVATE
    ${LLAMA_INCLUDE_DIR}
)

# 链接系统库
find_library(log-lib log)
find_library(android-lib android)

# 链接预编译的 libllama.so
target_link_libraries(llama_jni
    ${log-lib}
    ${android-lib}
    "${LLAMA_LIB_PATH}"  # 指向 jniLibs/arm64-v8a/libllama.so
)
```

**编译顺序**：
1. 首先编译 `libllama.so`（如果从源码编译）
2. 将 `libllama.so` 放置到 `jniLibs/arm64-v8a/`
3. 编译 `llama_jni.so`（JNI 桥接库）
4. Flutter 构建系统会自动打包所有 `.so` 文件到 APK

## 🐛 故障排除

### 模型加载失败

**错误信息**：
```
E/LlamaJNI: read error: Invalid argument
E/LlamaJNI: llama_model_load: error loading model
```

**解决方案**：
1. 确保模型文件在内部私有目录（不是 `/sdcard`）
2. 检查文件权限（应该是 644）
3. 验证文件完整性（文件大小是否正确）

### 权限问题

**错误信息**：
```
run-as: exec failed for test: Permission denied
```

**解决方案**：
1. 确保应用是 debug 版本
2. 确保应用至少运行过一次（创建 `app_flutter` 目录）
3. 如果仍有问题，可能需要 root 权限

### 模型文件不存在

**错误信息**：
```
模型文件不存在: /data/user/0/flyer.chat.flyer_chat/app_flutter/models/qwen2_5_3b.Q4_K_M.gguf
```

**解决方案**：
1. 运行部署脚本：`./scripts/deploy_model_to_internal.sh`
2. 手动检查文件是否存在：`adb shell "run-as flyer.chat.flyer_chat ls -l /data/data/flyer.chat.flyer_chat/app_flutter/models/"`
3. 确保应用至少运行过一次（创建 `app_flutter` 目录）

### libllama.so 加载失败

**错误信息**：
```
java.lang.UnsatisfiedLinkError: dlopen failed: library "libllama.so" not found
```

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

## 🔬 技术深度解析

### 为什么需要全局引用？

JNI 中的 `jobject` 是局部引用，只在当前 `JNIEnv` 和函数调用期间有效。在 C++ 后台线程中调用 Java 方法时：

1. **局部引用失效**：函数返回后，局部引用会被自动释放
2. **跨线程使用**：C++ 后台线程需要访问 Java 对象
3. **全局引用持久化**：使用 `NewGlobalRef` 创建的全局引用可以跨线程、跨函数使用

### 流式输出的性能优化

1. **异步处理**：生成过程在后台线程执行，不阻塞 UI
2. **批量更新**：使用 `notifyListeners()` 批量触发 UI 更新
3. **节流滚动**：流式输出时使用节流机制（200ms）控制滚动频率
4. **内存管理**：及时释放不需要的 token 和字符串

### KV Cache 管理

每次生成前清空 KV Cache，确保对话上下文的一致性：

```cpp
// 清空序列 0 的 KV Cache（从位置 -1 到 -1，即全部清空）
llama_memory_seq_rm(llama_get_memory(g_ctx), 0, -1, -1);
```

**为什么需要清空？**
- 避免前一次对话的上下文影响当前生成
- 确保 token 位置计算的一致性
- 防止 "inconsistent sequence positions" 错误

### 停止生成机制

1. **C++ 层**：使用全局标志 `g_should_stop`
   ```cpp
   static volatile bool g_should_stop = false;
   ```

2. **生成循环检查**：
   ```cpp
   while (n_cur < max_tokens && !g_should_stop) {
       // 生成 token...
   }
   ```

3. **Dart 层取消订阅**：
   ```dart
   subscription?.cancel();  // 取消 Stream 订阅
   await LlamaInference.stopGeneration();  // 设置停止标志
   ```

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

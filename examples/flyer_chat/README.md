# Flyer Chat - 本地大语言模型集成

一个基于 Flutter 的聊天应用，集成了本地大语言模型（LLM）推理能力，支持在 Android 设备上离线运行 Qwen2.5-3B 模型。

## 📋 目录

- [功能特性](#功能特性)
- [架构概览](#架构概览)
- [快速开始](#快速开始)
- [模型部署](#模型部署)
- [使用说明](#使用说明)
- [技术细节](#技术细节)
- [故障排除](#故障排除)
- [项目结构](#项目结构)

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

2. **部署模型文件**

将模型文件部署到 Android 设备的内部私有目录：

```bash
# 确保模型文件在本地路径
# 默认路径: /Users/admin/flutter_chat_ui/qwen2_5_3b.Q4_K_M.gguf

# 运行部署脚本
./scripts/deploy_model_to_internal.sh
```

3. **运行应用**

```bash
flutter run
```

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

#### 回调机制

使用 JNI 全局引用和回调接口实现跨线程通信：

```cpp
// 初始化回调
Java_flyer_chat_flyer_1chat_LlamaInference_initStreamCallback(
    JNIEnv *env, jclass clazz, jobject callback
);

// 发送 token 到 Java 层
void send_token_to_java(const char* token);
```

### 流式输出实现

1. **C++ 层**：在生成循环中，每生成一个 token 就调用 `send_token_to_java()`
2. **Kotlin 层**：实现 `StreamCallback` 接口，接收 token 并通过 `EventChannel` 发送
3. **Dart 层**：通过 `EventChannel.receiveBroadcastStream()` 接收 token 流
4. **UI 层**：使用 `SimpleStreamManager` 管理流式状态，实时更新 UI

### KV Cache 管理

每次生成前会清空 KV Cache，确保对话上下文的一致性：

```cpp
// 清空序列 0 的 KV Cache
llama_memory_seq_rm(llama_get_memory(g_ctx), 0, -1, -1);
```

### 文件系统配置

在 `llama_jni.cpp` 中配置模型加载参数：

```cpp
model_params.use_mmap = true;        // 启用内存映射
model_params.use_direct_io = false;   // 禁用 Direct I/O（Android 内部目录不需要）
model_params.use_mlock = false;       // 禁用内存锁定
```

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

### 应用冻结

**症状**：发送消息后应用无响应

**解决方案**：
- 确保流式生成在后台线程执行
- 检查 `runOnUiThread` 是否正确使用
- 查看日志确认是否有死锁

### 流式输出不显示

**症状**：AI 回复不显示或显示不完整

**解决方案**：
1. 检查 `EventChannel` 是否正确注册
2. 确认 `SimpleStreamManager` 是否正确初始化
3. 查看日志确认 token 是否正常接收

### KV Cache 错误

**错误信息**：
```
E/LlamaJNI: init: the tokens of sequence 0 in the input batch have inconsistent sequence positions
```

**解决方案**：
- 确保每次生成前清空 KV Cache
- 检查 token 位置计算是否正确

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

- [模型部署详细说明](scripts/LLAMA_MODEL_DEPLOYMENT.md)
- [Qwen 使用示例](lib/inference/QWEN_USAGE_EXAMPLE.md)
- [Llama 使用指南](LLAMA_USAGE.md)

## 🔗 相关链接

- [llama.cpp 官方文档](https://github.com/ggerganov/llama.cpp)
- [Qwen2.5 模型](https://huggingface.co/Qwen/Qwen2.5-3B-Instruct)
- [Flutter 平台通道文档](https://docs.flutter.dev/development/platform-integration/platform-channels)

## 📝 许可证

本项目遵循项目根目录的许可证。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

**注意**：本项目仅支持 Android 平台（arm64-v8a）。iOS 和其他平台的支持需要额外的配置和编译工作。

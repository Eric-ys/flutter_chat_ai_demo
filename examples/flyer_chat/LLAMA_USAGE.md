# Llama 本地推理使用指南

## 📋 概述

本实现提供了在 Android 设备上本地运行 Qwen2.5-3B 模型（GGUF 格式）的完整解决方案。

## 🔧 架构

- **JNI C++ 层** (`llama_jni.cpp`): 直接调用 llama.cpp API
- **Kotlin 层** (`LlamaInference.kt`, `MainActivity.kt`): MethodChannel 桥接
- **Dart 层** (`lib/inference/llama_inference.dart`): Flutter 接口

## 📦 文件结构

```
android/app/src/main/
├── cpp/
│   ├── llama_jni.cpp          # JNI C++ 实现
│   └── CMakeLists.txt          # CMake 配置
├── jniLibs/
│   └── arm64-v8a/
│       └── libllama.so         # 预编译的 llama.cpp 库
├── kotlin/flyer/chat/flyer_chat/
│   ├── LlamaInference.kt       # Native 方法声明
│   └── MainActivity.kt         # MethodChannel 注册
└── ...

lib/
└── inference/
    └── llama_inference.dart    # Dart 接口
```

## 🚀 使用方法

### 1. 加载模型

```dart
import 'package:flyer_chat/inference/llama_inference.dart';

// 使用默认路径加载模型
bool loaded = await LlamaInference.loadModel();
if (loaded) {
  print('模型加载成功');
} else {
  print('模型加载失败');
}

// 或指定自定义路径
bool loaded = await LlamaInference.loadModel(
  modelPath: '/path/to/your/model.gguf'
);
```

### 2. 生成文本

```dart
// 生成回复
String prompt = "你好！";
String reply = await LlamaInference.generate(prompt);
print('回复: $reply');
```

### 3. 卸载模型

```dart
// 释放资源
await LlamaInference.unloadModel();
```

### 4. 完整示例

```dart
import 'package:flyer_chat/inference/llama_inference.dart';

Future<void> main() async {
  // 检查模型文件是否存在
  bool exists = await LlamaInference.checkModelExists();
  if (!exists) {
    print('模型文件不存在，请将模型文件放置在: ${await LlamaInference.getModelPath()}');
    return;
  }
  
  // 加载模型
  bool loaded = await LlamaInference.loadModel();
  if (!loaded) {
    print('模型加载失败');
    return;
  }
  
  // 生成回复
  String prompt = "你好，请介绍一下你自己。";
  String reply = await LlamaInference.generate(prompt);
  print('回复: $reply');
  
  // 卸载模型
  await LlamaInference.unloadModel();
}
```

## ⚙️ 配置

### 模型路径

默认模型路径：`${应用文档目录}/models/qwen2_5_3b.Q4_K_M.gguf`

### 模型参数

在 `llama_jni.cpp` 中配置：

- `n_ctx = 2048`: 上下文大小
- `n_threads = 4`: 线程数（Android 推荐）
- `max_tokens = 256`: 最大生成 token 数
- 采样方式：Greedy（选择概率最大的 token）

## 🔍 调试

### 查看日志

```bash
# 查看 Android 日志
adb logcat | grep -E "LlamaJNI|LlamaInference"
```

### 常见问题

1. **模型加载失败**
   - 检查模型文件路径是否正确
   - 确认 `libllama.so` 在 `jniLibs/arm64-v8a/` 目录中
   - 检查模型文件是否损坏

2. **库加载失败**
   - 确认 `libllama.so` 和 `libllama_jni.so` 都已正确编译
   - 检查 ABI 架构是否匹配（当前仅支持 arm64-v8a）

3. **生成结果为空**
   - 检查 prompt 是否正确传递
   - 查看日志确认是否有错误信息

## 📝 注意事项

- 当前实现仅支持 **arm64-v8a** 架构
- 模型文件需要手动放置到设备中（不包含在 APK 中）
- 首次加载模型可能需要几秒钟时间
- 生成速度取决于设备性能和模型大小


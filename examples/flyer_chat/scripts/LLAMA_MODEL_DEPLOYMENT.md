# Llama 模型部署说明

## 问题背景

在使用 llama.cpp 加载 GGUF 模型时，如果模型文件位于 Android 的外部存储（`/sdcard`），可能会出现以下错误：

```
E/LlamaJNI: read error: Invalid argument
E/LlamaJNI: llama_model_load: error loading model
```

## 根本原因

Android 的 `/sdcard` 路径实际上是一个 **FUSE（Filesystem in Userspace）文件系统**，它是用户空间的文件系统实现。FUSE 文件系统有以下限制：

1. **不支持 Direct I/O**：llama.cpp 使用 Direct I/O（直接 I/O）来提高性能，但 FUSE 文件系统不支持 Direct I/O 操作
2. **I/O 开销**：所有 I/O 操作都需要经过 FUSE 内核模块，增加了延迟和开销
3. **内存映射限制**：大文件的 mmap 操作在 FUSE 文件系统上可能不稳定

## 解决方案

使用应用的**内部私有目录**（`/data/data/包名/app_flutter/`），该目录位于真实的文件系统（通常是 ext4），具有以下优势：

1. **支持 Direct I/O**：真实文件系统完全支持 Direct I/O，llama.cpp 可以正常工作
2. **性能更好**：直接访问文件系统，无需经过 FUSE 层
3. **无需权限**：内部私有目录无需存储权限，应用可以直接访问
4. **文件安全**：文件只能由应用本身访问，不会被其他应用或系统清理工具删除

## 路径对比

| 位置 | 路径示例 | 文件系统 | 支持 Direct I/O | 需要权限 |
|------|----------|----------|-----------------|----------|
| 外部存储 | `/sdcard/Android/data/flyer.chat.flyer_chat/files/` | FUSE | ❌ | ❌（应用目录无需权限，但根目录需要） |
| 内部私有目录 | `/data/user/0/flyer.chat.flyer_chat/app_flutter/` | ext4 | ✅ | ❌ |

## 使用方法

### 1. 部署模型文件

使用提供的脚本将模型文件部署到设备的内部目录：

```bash
cd examples/flyer_chat
./scripts/deploy_model_to_internal.sh
```

脚本会自动：
- 检查 adb 和设备连接
- 创建内部目录结构
- 复制模型文件
- 设置正确的文件权限
- 验证文件完整性

### 2. 代码集成

应用代码使用 `getApplicationDocumentsDirectory()` 获取内部目录路径：

```dart
import 'package:path_provider/path_provider.dart';

Future<String> getLocalModelPath() async {
  final Directory appDocDir = await getApplicationDocumentsDirectory();
  return '${appDocDir.path}/models/qwen2_5_3b.Q4_K_M.gguf';
}
```

### 3. 验证

运行应用后，检查日志确认模型加载成功：

```
✅ 模型文件已存在: /data/user/0/flyer.chat.flyer_chat/app_flutter/models/qwen2_5_3b.Q4_K_M.gguf
✅ Llama 模型加载成功
```

## 注意事项

1. **应用必须先运行一次**：首次运行应用会创建 `app_flutter` 目录，脚本才能正常工作
2. **Debug 版本**：脚本使用 `run-as` 命令，通常需要 debug 版本的 APK 或 root 权限
3. **文件大小**：确保设备有足够的存储空间（模型文件通常为 2-4GB）
4. **应用卸载**：卸载应用会删除内部目录中的所有文件，包括模型文件

## 技术细节

### Direct I/O 说明

Direct I/O 是一种绕过操作系统页面缓存的 I/O 方式，直接访问存储设备。它在以下场景特别有用：

- 大文件的顺序读取（如模型文件）
- 应用自身管理缓存的情况
- 需要可预测的 I/O 性能

llama.cpp 使用 Direct I/O 来：
- 减少内存使用（避免文件内容被缓存两次）
- 提高大文件加载性能
- 确保内存映射的稳定性

### FUSE 文件系统限制

FUSE 文件系统在用户空间实现，所有 I/O 操作都需要经过：
1. 系统调用（read/write）
2. FUSE 内核模块
3. 用户空间 FUSE 守护进程
4. 实际文件系统（如 ext4）

这个额外的层导致：
- Direct I/O 操作被转换为普通 I/O
- 性能开销增加
- 某些高级特性（如 Direct I/O）无法支持

## 参考

- [Android 存储概览](https://developer.android.com/training/data-storage)
- [llama.cpp Direct I/O](https://github.com/ggerganov/llama.cpp)
- [FUSE 文件系统](https://en.wikipedia.org/wiki/Filesystem_in_Userspace)


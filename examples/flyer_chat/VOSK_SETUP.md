# Vosk 语音识别集成说明

本项目已集成 Vosk 离线语音识别 SDK，无需 Google 语音服务即可使用语音输入功能。

## 模型文件配置

### 1. 下载 Vosk 模型

从 [Vosk 官方模型页面](https://alphacephei.com/vosk/models) 下载适合的模型：

**推荐模型（中文）：**
- 小模型：`vosk-model-small-cn-0.3` (约 40MB) - 适合移动设备
- 中模型：`vosk-model-cn-0.3` (约 1.5GB) - 准确率更高

**其他语言：**
- 英文：`vosk-model-small-en-us-0.15`
- 更多语言请访问官方页面

### 2. 配置模型文件

#### 方式一：放在 assets 目录（推荐）

1. 下载并解压模型文件
2. 将解压后的模型文件夹（如 `vosk-model-small-cn-0.3`）复制到：
   ```
   examples/flyer_chat/android/app/src/main/assets/
   ```
3. 确保 `pubspec.yaml` 中已配置 assets：
   ```yaml
   flutter:
     assets:
       - vosk-model-small-cn-0.3/
   ```

#### 方式二：放在应用内部存储

1. 首次运行时，将模型从 assets 复制到内部存储
2. 在代码中指定模型路径

### 3. 修改模型路径（如需要）

在 `VoskSpeechRecognition.kt` 中修改 `MODEL_PATH` 常量：

```kotlin
private const val MODEL_PATH = "vosk-model-small-cn-0.3"
```

或在 Flutter 代码中指定：

```dart
await _voskRecognition.initialize(
  modelPath: '/path/to/your/model'
);
```

## 权限配置

确保 `AndroidManifest.xml` 中已包含录音权限：

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

## 使用说明

1. 首次运行应用时，Vosk 会自动初始化模型
2. 长按输入框右侧的麦克风按钮开始语音输入
3. 松开按钮结束录音并发送识别结果
4. 识别过程中，文字会实时显示在输入框中

## 注意事项

- **模型文件较大**：首次下载和加载模型需要一些时间
- **离线工作**：Vosk 完全离线工作，无需网络连接
- **设备性能**：较大模型需要更好的设备性能
- **内存占用**：模型会占用一定内存，建议使用小模型

## 故障排除

### 模型加载失败
- 检查模型文件路径是否正确
- 确认模型文件完整性
- 查看 logcat 日志获取详细错误信息

### 识别不准确
- 尝试使用更大的模型
- 确保环境安静，减少背景噪音
- 说话清晰，语速适中

### 权限问题
- 确保已授予麦克风权限
- 在系统设置中检查应用权限

## 性能优化建议

1. **模型选择**：根据设备性能选择合适的模型大小
2. **延迟加载**：首次使用时再加载模型，避免启动延迟
3. **缓存模型**：将模型放在内部存储，避免每次从 assets 复制


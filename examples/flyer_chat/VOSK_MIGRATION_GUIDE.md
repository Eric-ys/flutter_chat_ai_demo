# Vosk Android 迁移指南

## 概述

本指南说明如何将项目从基于 JNA 的 Vosk Java 封装迁移到官方 Vosk Android AAR 库，以解决 `UnsatisfiedLinkError: libjnidispatch.so not found` 错误。

## 迁移步骤

### 1. 下载 Vosk Android AAR 文件

**下载位置：**
- Maven Central: https://repo1.maven.org/maven2/com/alphacephei/vosk-android/
- 推荐版本: 0.3.46 或更高版本

**下载链接示例：**
```
https://repo1.maven.org/maven2/com/alphacephei/vosk-android/0.3.46/vosk-android-0.3.46.aar
```

**安装步骤：**
1. 下载 `vosk-android-x.x.xx.aar` 文件
2. 将文件放入 `android/app/libs/` 目录
3. 可以重命名为 `vosk-android.aar`（可选）

### 2. 目录结构变更

```
android/app/
├── libs/
│   ├── vosk-android.aar          # 下载的 AAR 文件（必需）
│   └── README.md                  # AAR 文件说明
├── build.gradle.kts               # 已更新，使用本地 AAR
└── src/main/
    ├── AndroidManifest.xml        # 已包含 RECORD_AUDIO 权限
    └── kotlin/.../
        └── VoskSpeechRecognition.kt  # 已重写，使用纯 JNI API
```

### 3. build.gradle.kts 变更

**主要变更：**
- ✅ 使用本地 AAR 文件（`libs/vosk-android*.aar`）
- ✅ 完全排除所有 JNA 相关依赖
- ✅ 如果找不到本地 AAR，回退到 Maven（不推荐）

**关键配置：**
```kotlin
configurations.all {
    exclude(group = "net.java.dev.jna", module = "jna")
    exclude(group = "net.java.dev.jna", module = "jna-platform")
    exclude(group = "net.sourceforge.vosk", module = "vosk")
    exclude(group = "com.sun.jna", module = "*")
}

dependencies {
    // 优先使用本地 AAR
    val voskAarFiles = fileTree("libs") {
        include("vosk-android*.aar")
    }
    if (voskAarFiles.files.isNotEmpty()) {
        implementation(files(voskAarFiles.files.first().absolutePath))
    } else {
        // 回退到 Maven（不推荐）
        implementation("com.alphacephei:vosk-android:0.3.46")
    }
}
```

### 4. VoskSpeechRecognition.kt 变更

**主要变更：**
- ✅ 使用 `org.vosk.Model` 和 `org.vosk.Recognizer`（来自 vosk-android AAR）
- ✅ 完全移除所有 JNA 引用
- ✅ 模型文件从 assets 复制到内部存储（`/data/user/0/.../files/model`）
- ✅ 保持 MethodChannel 接口不变

**关键 API 使用：**
```kotlin
// 加载模型（纯 JNI，不依赖 JNA）
model = Model(internalModelPath)

// 创建识别器（纯 JNI，不依赖 JNA）
recognizer = Recognizer(model, SAMPLE_RATE)

// 处理音频数据
recognizer.acceptWaveForm(buffer, bytesRead)
```

### 5. AndroidManifest.xml 权限

**已包含的权限：**
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

**注意：** 在运行时还需要动态请求录音权限（Android 6.0+）。

### 6. ProGuard 规则

**已更新的规则：**
- 保留所有 `org.vosk.**` 类
- 保留原生方法（JNI 绑定）
- 保留 JSON 解析类
- 保留自定义包装类

## 模型文件处理

### 模型文件位置

1. **Assets 目录：** `android/app/src/main/assets/vosk-model-small-cn-0.3/`
   - 应用打包时包含的模型文件

2. **内部存储：** `/data/user/0/[package_name]/files/vosk-model-small-cn-0.3/`
   - 运行时从 assets 复制到此位置
   - Vosk 从此位置加载模型

### 模型复制流程

1. 应用启动时，检查内部存储是否已有模型
2. 如果不存在，从 assets 递归复制到内部存储
3. 使用内部存储路径初始化 Model

## 验证迁移

### 1. 检查依赖

运行以下命令检查依赖树，确认没有 JNA 相关依赖：

```bash
cd android
./gradlew :app:dependencies | grep -i jna
```

**预期结果：** 不应该有任何 JNA 相关输出。

### 2. 检查 AAR 文件

确认 AAR 文件已正确放置：

```bash
ls -lh android/app/libs/vosk-android*.aar
```

### 3. 构建测试

```bash
cd android
./gradlew clean
./gradlew :app:assembleDebug
```

### 4. 运行时测试

- 确保应用可以正常初始化 Vosk
- 确保可以开始和停止语音识别
- 检查 logcat 中是否有 JNA 相关错误

## 常见问题

### Q: 仍然出现 JNA 相关错误？

**A:** 检查以下几点：
1. 确认已下载并放置 AAR 文件到 `libs/` 目录
2. 确认 `build.gradle.kts` 中的排除规则已生效
3. 运行 `./gradlew clean` 清理构建缓存
4. 检查是否有其他依赖引入了 JNA

### Q: 模型加载失败？

**A:** 检查以下几点：
1. 确认模型文件在 `assets/` 目录中
2. 检查内部存储权限
3. 查看 logcat 中的详细错误信息

### Q: 语音识别不工作？

**A:** 检查以下几点：
1. 确认已授予录音权限
2. 检查 AudioRecord 初始化是否成功
3. 查看 logcat 中的音频相关错误

## 技术细节

### JNI vs JNA

- **JNI (Java Native Interface):** 标准 Java 原生接口，Android 原生支持
- **JNA (Java Native Access):** 第三方库，在 Android 上不可靠

### Vosk Android AAR

- **包名：** `org.vosk`
- **主要类：** `Model`, `Recognizer`
- **实现方式：** 纯 JNI，通过 `System.loadLibrary("vosk")` 加载
- **原生库：** 包含在 AAR 中，自动打包到 APK

## 参考资源

- Vosk Android GitHub: https://github.com/alphacep/vosk-android
- Vosk 官方文档: https://alphacephei.com/vosk/
- Maven Central: https://repo1.maven.org/maven2/com/alphacephei/vosk-android/

## 迁移完成检查清单

- [ ] AAR 文件已下载并放入 `libs/` 目录
- [ ] `build.gradle.kts` 已更新为使用本地 AAR
- [ ] 所有 JNA 相关依赖已排除
- [ ] `VoskSpeechRecognition.kt` 已重写
- [ ] `AndroidManifest.xml` 包含录音权限
- [ ] ProGuard 规则已更新
- [ ] 模型文件在 `assets/` 目录中
- [ ] 构建成功，无 JNA 相关错误
- [ ] 运行时测试通过


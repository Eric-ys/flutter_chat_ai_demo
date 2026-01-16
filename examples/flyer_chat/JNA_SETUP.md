# Vosk Android 配置说明

## ⚠️ 实际情况

**经过验证，`vosk-android:0.3.45` AAR 内部的类确实使用了 JNA：**
- `org.vosk.Recognizer extends com.sun.jna.PointerType`
- `org.vosk.Model extends com.sun.jna.PointerType`

**因此需要：**
1. 添加 JNA 依赖（用于编译）
2. 手动提供 JNA 原生库 `libjnidispatch.so`（用于运行时）

## 📌 官方事实

1. **官方 AAR 无依赖**：`com.alphacephei:vosk-android:0.3.45` 在 Maven Central 上是无依赖的（dependency-free）
2. **纯 JNI 实现**：使用标准 `System.loadLibrary("vosk")` 加载本地库
3. **手写 JNI 绑定**：通过手写的 JNI 绑定调用 C 函数，不通过 JNA

## ❌ 常见误解

### 误解 1：vosk-android 需要 JNA
- **错误**：某些教程或过时文档可能提到需要 JNA
- **事实**：只有桌面版 `net.sourceforge.vosk:vosk` 使用 JNA，Android 版不使用

### 误解 2：需要手动放置 libjnidispatch.so
- **错误**：这是桌面版 JNA 的需求
- **事实**：Android 版只需要 `libvosk.so`，由 AAR 自动提供

## ✅ 正确配置

### build.gradle.kts

```kotlin
dependencies {
    // 只使用官方 Android AAR，不需要 JNA
    implementation("com.alphacephei:vosk-android:0.3.45")
    // ❌ 不要添加以下依赖：
    // implementation("net.java.dev.jna:jna:5.13.0")
}
```

### 验证方法

1. **检查依赖树**：
   ```bash
   ./gradlew :app:dependencies --configuration debugRuntimeClasspath | grep -i jna
   ```
   应该没有 JNA 相关输出

2. **检查 APK**：
   - ✅ 应该有 `lib/arm64-v8a/libvosk.so`
   - ❌ 不应该有 `lib/arm64-v8a/libjnidispatch.so`
   - ❌ 不应该有 `com/sun/jna/` 包

3. **检查 POM 文件**：
   访问 https://repo1.maven.org/maven2/com/alphacephei/vosk-android/0.3.45/vosk-android-0.3.45.pom
   应该没有 `<dependencies>` 节点

## 🔍 如果遇到 JNA 相关错误

如果仍然看到 `UnsatisfiedLinkError: libjnidispatch.so not found`，可能的原因：

### 情况 1：AAR 内部包含 JNA 类

**问题**：某些版本的 `vosk-android` AAR 可能内部包含了使用 JNA 的类（即使 POM 文件显示无依赖）。

**症状**：
- 错误堆栈显示 `org.vosk.LibVosk.<clinit>` 调用 `com.sun.jna.Native.register`
- 即使排除了传递依赖，仍然报错

**临时解决方案**（不推荐，但可以工作）：
1. 添加 JNA 依赖和原生库：
   ```kotlin
   implementation("net.java.dev.jna:jna:5.13.0")
   ```
2. 将 `libjnidispatch.so` 放到 `jniLibs` 目录（见下方说明）

**更好的解决方案**：
- 尝试使用更新的版本（如 0.3.47, 0.3.70）
- 或者联系维护者报告问题
- 或者考虑使用其他语音识别库

### 情况 2：依赖污染

项目中可能有其他库引入了 JNA 版本的 Vosk：
- 检查是否有 `net.sourceforge.vosk:vosk` 依赖
- 检查是否有其他库间接引入了 JNA

### 情况 3：错误的类加载

代码可能加载了桌面版的 `org.vosk.LibVosk`：
- 确保只使用 `com.alphacephei:vosk-android` 中的类

## 📦 临时解决方案：添加 JNA 原生库

如果 AAR 内部确实需要 JNA，可以手动添加原生库：

1. 下载 JNA JAR 并提取原生库：
   ```bash
   wget https://repo1.maven.org/maven2/net/java/dev/jna/jna/5.13.0/jna-5.13.0.jar
   unzip -q jna-5.13.0.jar
   ```

2. 复制原生库到项目：
   ```bash
   cp com/sun/jna/android-aarch64/libjnidispatch.so android/app/src/main/jniLibs/arm64-v8a/
   cp com/sun/jna/android-armeabi-v7a/libjnidispatch.so android/app/src/main/jniLibs/armeabi-v7a/
   ```

3. 添加 JNA 依赖：
   ```kotlin
   implementation("net.java.dev.jna:jna:5.13.0")
   ```

## 📚 参考

- 官方 GitHub：https://github.com/alphacep/vosk-api/tree/master/android
- Maven Central POM：https://repo1.maven.org/maven2/com/alphacephei/vosk-android/0.3.45/vosk-android-0.3.45.pom

# EchoAI 应用图标设置指南

## 已完成的配置

✅ 应用名称已修改为 **EchoAI**
- Android: `android/app/src/main/AndroidManifest.xml`
- iOS: `ios/Runner/Info.plist`
- macOS: 需要手动更新（见下方）

## 图标设置步骤

### 1. 保存图标文件

请将您提供的应用图标图片保存为：
```
examples/flyer_chat/assets/icon/app_icon.png
```

**图标要求：**
- 格式：PNG（推荐透明背景）
- 尺寸：至少 1024x1024 像素
- 内容：您提供的 AI 聊天气泡图标

### 2. 生成所有尺寸的图标

保存图片后，在项目根目录运行：

```bash
cd examples/flyer_chat
flutter pub get
flutter pub run flutter_launcher_icons
```

这将自动为 Android 和 iOS 生成所有所需尺寸的图标。

### 3. 验证图标

生成完成后，您可以：
- **Android**: 检查 `android/app/src/main/res/mipmap-*/ic_launcher.png`
- **iOS**: 检查 `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

### 4. macOS 配置（可选）

如果需要为 macOS 设置图标，请手动更新：
- `macos/Runner/Info.plist` 中的 `CFBundleDisplayName` 和 `CFBundleName` 为 "EchoAI"

## 注意事项

- 如果图标生成失败，请确保图片路径正确
- 建议使用透明背景的 PNG 图片以获得最佳效果
- 图标会自动适配 Android 的 adaptive icon 和 iOS 的各种尺寸


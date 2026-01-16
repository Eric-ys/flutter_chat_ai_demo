# 应用图标说明

请将应用图标图片保存为 `app_icon.png` 并放置在此目录下。

图标要求：
- 格式：PNG
- 尺寸：建议至少 1024x1024 像素
- 背景：透明或纯色（推荐透明背景）

保存图片后，运行以下命令生成所有尺寸的图标：

```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

这将自动为 Android 和 iOS 生成所有所需尺寸的图标。

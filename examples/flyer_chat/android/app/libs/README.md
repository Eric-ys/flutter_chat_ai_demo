# Vosk Android AAR 文件说明

## 下载 AAR 文件

请从以下位置下载最新版本的 vosk-android AAR 文件：

1. **Maven Central**: https://repo1.maven.org/maven2/com/alphacephei/vosk-android/
2. **GitHub Releases**: https://github.com/alphacep/vosk-android/releases

## 推荐版本

- **最新稳定版**: 0.3.46 或更高版本
- **下载链接示例**: 
  ```
  https://repo1.maven.org/maven2/com/alphacephei/vosk-android/0.3.46/vosk-android-0.3.46.aar
  ```

## 安装步骤

1. 下载 `vosk-android-x.x.xx.aar` 文件
2. 将文件重命名为 `vosk-android.aar`（可选，但推荐）
3. 将文件放入此目录：`android/app/libs/vosk-android.aar`

## 验证

下载完成后，此目录应包含：
- `vosk-android.aar`（或 `vosk-android-0.3.46.aar`）
- `README.md`（本文件）

## 注意事项

- AAR 文件包含所有必要的原生库（.so 文件）
- 不需要手动提取或配置原生库
- 确保 AAR 版本与代码中使用的 API 兼容


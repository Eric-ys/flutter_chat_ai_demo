#!/bin/bash
# 清理 Vosk 相关缓存和构建文件
# 确保使用官方 Android AAR 版本

echo "🧹 开始清理 Vosk 相关缓存..."

# 1. 清理 Flutter
echo "📦 清理 Flutter..."
cd "$(dirname "$0")"
flutter clean

# 2. 清理 Android Gradle
echo "📦 清理 Android Gradle..."
cd android
./gradlew clean

# 3. 清理 Gradle 缓存（重要！）
echo "🗑️  清理 Gradle 全局缓存..."
# 清理损坏的 Kotlin DSL 缓存
rm -rf ~/.gradle/caches/8.12/kotlin-dsl/ 2>/dev/null
# 清理整个 Gradle 8.12 缓存（如果上面的不够）
rm -rf ~/.gradle/caches/8.12/ 2>/dev/null
# 清理所有 Gradle 缓存（最彻底，但会重新下载所有依赖）
# rm -rf ~/.gradle/caches/

# 4. 清理本地构建目录
echo "🗑️  清理本地构建目录..."
rm -rf build/
rm -rf android/app/build/
rm -rf android/.gradle/

# 5. 返回项目根目录
cd ..

# 6. 重新获取依赖
echo "📥 重新获取依赖..."
flutter pub get

echo "✅ 清理完成！"
echo ""
echo "现在可以运行: flutter run"


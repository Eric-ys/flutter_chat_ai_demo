#!/bin/bash
# 下载并安装 JNA Android 原生库

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
JNI_LIBS_DIR="$PROJECT_DIR/android/app/src/main/jniLibs"
TMP_DIR="/tmp/jna_extract_$$"

echo "📥 下载 JNA 原生库..."

# 创建临时目录
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

# 下载 JNA JAR
echo "下载 JNA 5.13.0 JAR..."
curl -L -o jna.jar https://repo1.maven.org/maven2/net/java/dev/jna/jna/5.13.0/jna-5.13.0.jar

# 解压 JAR
echo "解压 JAR..."
unzip -q jna.jar

# 检查是否有 Android 原生库
if [ -d "com/sun/jna/android-aarch64" ]; then
    echo "✅ 找到 Android 原生库"
    
    # 创建目标目录
    mkdir -p "$JNI_LIBS_DIR/arm64-v8a"
    mkdir -p "$JNI_LIBS_DIR/armeabi-v7a"
    mkdir -p "$JNI_LIBS_DIR/x86_64"
    mkdir -p "$JNI_LIBS_DIR/x86"
    
    # 复制原生库
    if [ -f "com/sun/jna/android-aarch64/libjnidispatch.so" ]; then
        cp "com/sun/jna/android-aarch64/libjnidispatch.so" "$JNI_LIBS_DIR/arm64-v8a/"
        echo "✅ 已复制 arm64-v8a/libjnidispatch.so"
    fi
    
    if [ -f "com/sun/jna/android-armeabi-v7a/libjnidispatch.so" ]; then
        cp "com/sun/jna/android-armeabi-v7a/libjnidispatch.so" "$JNI_LIBS_DIR/armeabi-v7a/"
        echo "✅ 已复制 armeabi-v7a/libjnidispatch.so"
    fi
    
    if [ -f "com/sun/jna/android-x86_64/libjnidispatch.so" ]; then
        cp "com/sun/jna/android-x86_64/libjnidispatch.so" "$JNI_LIBS_DIR/x86_64/"
        echo "✅ 已复制 x86_64/libjnidispatch.so"
    fi
    
    if [ -f "com/sun/jna/android-x86/libjnidispatch.so" ]; then
        cp "com/sun/jna/android-x86/libjnidispatch.so" "$JNI_LIBS_DIR/x86/"
        echo "✅ 已复制 x86/libjnidispatch.so"
    fi
else
    echo "⚠️  JAR 中未找到 Android 原生库"
    echo "尝试使用 Linux 版本（不推荐，可能不兼容）..."
    
    # 使用 Linux 版本作为备选
    mkdir -p "$JNI_LIBS_DIR/arm64-v8a"
    mkdir -p "$JNI_LIBS_DIR/armeabi-v7a"
    
    if [ -f "com/sun/jna/linux-aarch64/libjnidispatch.so" ]; then
        cp "com/sun/jna/linux-aarch64/libjnidispatch.so" "$JNI_LIBS_DIR/arm64-v8a/libjnidispatch.so"
        echo "⚠️  已复制 Linux aarch64 版本到 arm64-v8a（可能不兼容）"
    fi
    
    if [ -f "com/sun/jna/linux-arm/libjnidispatch.so" ]; then
        cp "com/sun/jna/linux-arm/libjnidispatch.so" "$JNI_LIBS_DIR/armeabi-v7a/libjnidispatch.so"
        echo "⚠️  已复制 Linux arm 版本到 armeabi-v7a（可能不兼容）"
    fi
fi

# 清理
cd /
rm -rf "$TMP_DIR"

echo ""
echo "✅ 完成！"
echo "原生库位置："
ls -lh "$JNI_LIBS_DIR"/*/libjnidispatch.so 2>/dev/null || echo "未找到原生库文件"


#!/bin/bash
# 验证 Vosk 配置是否正确（方案 A）

echo "🔍 验证 Vosk 配置（方案 A - 官方 Android AAR）..."
echo ""

cd "$(dirname "$0")"

# 1. 检查 build.gradle.kts
echo "1️⃣  检查 build.gradle.kts..."
if grep -q "com.alphacephei:vosk-android" android/app/build.gradle.kts; then
    echo "   ✅ 找到官方 Android AAR: com.alphacephei:vosk-android"
else
    echo "   ❌ 未找到官方 Android AAR"
fi

if grep -q "net.sourceforge.vosk:vosk" android/app/build.gradle.kts; then
    echo "   ❌ 发现桌面 JNA 版 Vosk（应该删除）"
else
    echo "   ✅ 未发现桌面 JNA 版 Vosk"
fi

if grep -q "net.java.dev.jna:jna" android/app/build.gradle.kts; then
    echo "   ❌ 发现 JNA 依赖（应该删除）"
else
    echo "   ✅ 未发现 JNA 依赖"
fi

# 2. 检查全局排除配置
echo ""
echo "2️⃣  检查全局排除配置..."
if grep -q "configurations.all" android/app/build.gradle.kts && grep -q "exclude.*jna" android/app/build.gradle.kts; then
    echo "   ✅ 找到全局排除 JNA 配置"
else
    echo "   ⚠️  未找到全局排除配置（建议添加）"
fi

# 3. 检查代码中是否有 JNA 特定 API
echo ""
echo "3️⃣  检查代码中是否有 JNA 特定 API..."
if grep -r "Pointer\|Memory\|Native.register\|com.sun.jna" android/app/src/main/kotlin/ 2>/dev/null; then
    echo "   ❌ 发现 JNA 特定 API（应该移除）"
else
    echo "   ✅ 未发现 JNA 特定 API"
fi

# 4. 检查依赖树
echo ""
echo "4️⃣  检查依赖树..."
cd android
if ./gradlew :app:dependencies --configuration debugRuntimeClasspath 2>&1 | grep -i "net.sourceforge.vosk\|net.java.dev.jna" | grep -v "excluded"; then
    echo "   ❌ 依赖树中发现 JNA 或桌面版 Vosk"
else
    echo "   ✅ 依赖树中未发现 JNA 或桌面版 Vosk"
fi

echo ""
echo "✅ 验证完成！"
echo ""
echo "如果所有检查都通过 ✅，可以运行: flutter run"


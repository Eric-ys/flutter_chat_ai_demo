#!/bin/bash

# 将模型文件部署到 Android 设备的内部私有目录
# 
# 用途：解决 llama.cpp 在 Android FUSE 文件系统（/sdcard）上的 Direct I/O 错误
# 原理：使用应用内部私有目录（/data/user/0/flyer.chat.flyer_chat/app_flutter/）
#       该目录位于真实文件系统，支持 Direct I/O，无需存储权限

set -e  # 遇到错误立即退出

# 配置
PACKAGE_NAME="flyer.chat.flyer_chat"
MODEL_NAME="qwen2_5_3b.Q4_K_M.gguf"
LOCAL_MODEL_PATH="/Users/admin/flutter_chat_ui/qwen2_5_3b.Q4_K_M.gguf"
INTERNAL_BASE_DIR="/data/data/${PACKAGE_NAME}/app_flutter"
INTERNAL_MODEL_DIR="${INTERNAL_BASE_DIR}/models"
INTERNAL_MODEL_PATH="${INTERNAL_MODEL_DIR}/${MODEL_NAME}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${GREEN}ℹ️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# 检查 adb 是否可用
if ! command -v adb &> /dev/null; then
    print_error "adb 命令未找到。请确保 Android SDK platform-tools 在 PATH 中。"
    exit 1
fi

# 检查设备连接
if ! adb devices | grep -q "device$"; then
    print_error "未检测到已连接的 Android 设备。"
    echo "请确保："
    echo "1. 设备已通过 USB 连接到电脑"
    echo "2. 已启用 USB 调试"
    echo "3. 已授权此电脑进行 USB 调试"
    exit 1
fi

print_info "检测到已连接的 Android 设备"

# 检查本地模型文件是否存在
if [ ! -f "$LOCAL_MODEL_PATH" ]; then
    print_error "本地模型文件不存在: $LOCAL_MODEL_PATH"
    exit 1
fi

print_info "本地模型文件: $LOCAL_MODEL_PATH"
FILE_SIZE=$(du -h "$LOCAL_MODEL_PATH" | cut -f1)
print_info "文件大小: $FILE_SIZE"

# 检查应用是否已安装
if ! adb shell pm list packages | grep -q "^package:${PACKAGE_NAME}$"; then
    print_error "应用未安装: $PACKAGE_NAME"
    echo "请先安装应用，然后再次运行此脚本。"
    exit 1
fi

print_info "应用已安装: $PACKAGE_NAME"

# 使用 run-as 切换到应用用户并创建目录
print_info "创建内部目录: $INTERNAL_MODEL_DIR"
adb shell "run-as ${PACKAGE_NAME} mkdir -p ${INTERNAL_MODEL_DIR}" || {
    print_error "无法创建目录。请确保："
    echo "1. 应用已至少运行过一次（首次运行会创建 app_flutter 目录）"
    echo "2. 设备已 root 或应用是 debug 版本"
    exit 1
}

# 将模型文件复制到设备的临时位置（/sdcard 是 FUSE，但可以用于临时存储）
TEMP_PATH="/sdcard/tmp_${MODEL_NAME}"
print_info "将模型文件复制到临时位置: $TEMP_PATH"
adb push "$LOCAL_MODEL_PATH" "$TEMP_PATH" || {
    print_error "无法推送文件到设备"
    exit 1
}

# 从临时位置复制到内部目录并设置权限
print_info "将文件从临时位置复制到内部目录"
COPY_OUTPUT=$(adb shell "run-as ${PACKAGE_NAME} cp ${TEMP_PATH} ${INTERNAL_MODEL_PATH} 2>&1")
COPY_EXIT_CODE=$?

if [ $COPY_EXIT_CODE -ne 0 ]; then
    print_error "无法复制文件到内部目录"
    print_error "错误信息: $COPY_OUTPUT"
    # 清理临时文件
    adb shell rm -f "$TEMP_PATH"
    exit 1
fi

# 设置文件权限（644：所有者读写，组和其他只读）
print_info "设置文件权限"
adb shell "run-as ${PACKAGE_NAME} chmod 644 ${INTERNAL_MODEL_PATH}" || {
    print_warning "无法设置文件权限（可能已具有正确权限）"
}

# 清理临时文件
print_info "清理临时文件"
adb shell rm -f "$TEMP_PATH"

# 验证文件是否成功复制
# 使用 ls 命令而不是 test，因为某些 Android 版本的 run-as 对 test 有限制
print_info "验证文件是否成功复制..."
FILE_CHECK=$(adb shell "run-as ${PACKAGE_NAME} ls -l ${INTERNAL_MODEL_PATH} 2>&1")
if echo "$FILE_CHECK" | grep -q "No such file"; then
    print_error "文件部署失败：文件不存在于目标位置"
    print_error "请检查上面的错误信息"
    exit 1
elif echo "$FILE_CHECK" | grep -q "Permission denied"; then
    print_warning "无法直接验证文件（权限限制），但文件可能已成功复制"
    print_warning "请运行应用检查模型是否能正常加载"
    print_info "预期路径: $INTERNAL_MODEL_PATH"
else
    print_info "✅ 模型文件部署成功！"
    print_info "内部路径: $INTERNAL_MODEL_PATH"
    
    # 获取文件大小（用于验证）
    # 从 ls -l 输出中提取文件大小（第5列）
    REMOTE_SIZE=$(echo "$FILE_CHECK" | awk '{print $5}')
    LOCAL_SIZE=$(stat -f%z "$LOCAL_MODEL_PATH" 2>/dev/null || stat -c%s "$LOCAL_MODEL_PATH" 2>/dev/null)
    
    if [ -n "$REMOTE_SIZE" ] && [ "$REMOTE_SIZE" = "$LOCAL_SIZE" ]; then
        print_info "✅ 文件大小验证通过: $REMOTE_SIZE 字节"
    elif [ -n "$REMOTE_SIZE" ]; then
        print_warning "文件大小不匹配"
        print_warning "本地: $LOCAL_SIZE 字节"
        print_warning "远程: $REMOTE_SIZE 字节"
        print_warning "如果大小差异很大，可能需要重新部署"
    else
        print_warning "无法获取远程文件大小，但文件已存在"
    fi
fi

print_info "部署完成！现在可以运行应用了。"


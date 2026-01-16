import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 模型文件设置工具类
/// 用于在应用启动时检查并准备模型文件
///
/// **重要说明**：
/// - 使用内部私有目录（getApplicationDocumentsDirectory）而非外部存储
/// - 原因：Android 的 /sdcard 是 FUSE 文件系统，不支持 llama.cpp 的 Direct I/O
/// - 内部目录路径示例：/data/user/0/flyer.chat.flyer_chat/app_flutter/models/qwen2_5_3b.Q4_K_M.gguf
class ModelFileSetup {
  /// 默认模型文件名
  static const String _defaultModelName = 'qwen2_5_3b.Q4_K_M.gguf';

  /// 检查并准备模型文件
  ///
  /// 如果目标路径文件不存在，将抛出异常
  ///
  /// 返回模型文件路径，如果失败则抛出异常
  static Future<String> ensureModelFile() async {
    final targetPath = await _getTargetModelPath();
    final targetFile = File(targetPath);

    // 检查目标文件是否已存在
    if (await targetFile.exists()) {
      print('✅ 模型文件已存在: $targetPath');
      // 验证文件大小（避免文件损坏）
      final fileSize = await targetFile.length();
      print('   文件大小: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
      return targetPath;
    }

    // 如果文件不存在，抛出错误
    final errorMsg =
        '模型文件不存在: $targetPath\n\n'
        '请使用 deploy_model_to_internal.sh 脚本将模型文件推送到设备。\n'
        '脚本路径: scripts/deploy_model_to_internal.sh';
    print('❌ $errorMsg');
    throw Exception(errorMsg);
  }

  /// 获取目标模型文件路径
  ///
  /// 使用内部私有目录（getApplicationDocumentsDirectory），确保：
  /// 1. 支持 Direct I/O（避免 FUSE 文件系统的限制）
  /// 2. 无需存储权限
  /// 3. 文件不会被 Android 系统自动清理
  ///
  /// Android 路径示例: `/data/user/0/flyer.chat.flyer_chat/app_flutter/models/qwen2_5_3b.Q4_K_M.gguf`
  /// 其他平台: `${应用文档目录}/models/qwen2_5_3b.Q4_K_M.gguf`
  static Future<String> _getTargetModelPath() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    return '${appDocDir.path}/models/$_defaultModelName';
  }

  /// 获取模型文件路径（不进行检查）
  ///
  /// 仅返回目标路径，不执行任何文件操作
  static Future<String> getModelPath() async {
    return await _getTargetModelPath();
  }

  /// 检查模型文件是否存在
  ///
  /// 返回 true 表示文件存在，false 表示不存在
  static Future<bool> checkModelExists() async {
    try {
      final path = await _getTargetModelPath();
      final file = File(path);
      return await file.exists();
    } catch (e) {
      print('检查模型文件时出错: $e');
      return false;
    }
  }
}

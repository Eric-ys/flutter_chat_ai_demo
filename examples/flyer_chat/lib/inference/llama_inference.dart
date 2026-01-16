import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';

/// Llama 本地推理类
/// 通过 MethodChannel 调用 Android 原生代码，使用 llama.cpp 进行本地 LLM 推理
class LlamaInference {
  static const MethodChannel _channel = MethodChannel(
    'flyer.chat.flyer_chat/llama',
  );

  static const EventChannel _streamChannel = EventChannel(
    'flyer.chat.flyer_chat/llama_stream',
  );

  /// 默认模型文件名
  static const String _defaultModelName = 'qwen2_5_3b.Q4_K_M.gguf';

  /// 加载模型
  ///
  /// [modelPath] 模型文件路径，如果为 null 则使用默认路径：
  /// Android: `/sdcard/Android/data/flyer.chat.flyer_chat/files/models/qwen2_5_3b.Q4_K_M.gguf`
  /// 其他平台: `${应用程序文档目录}/models/qwen2_5_3b.Q4_K_M.gguf`
  ///
  /// 返回 true 表示加载成功，false 表示失败
  static Future<bool> loadModel({String? modelPath}) async {
    try {
      String path = modelPath ?? await _getDefaultModelPath();

      final bool result =
          await _channel.invokeMethod<bool>('loadModel', {'modelPath': path}) ??
          false;

      return result;
    } on PlatformException catch (e) {
      print(
        'LlamaInference.loadModel PlatformException: ${e.code} - ${e.message}',
      );
      rethrow;
    } catch (e) {
      print('LlamaInference.loadModel Exception: $e');
      rethrow;
    }
  }

  /// 生成文本回复（同步，返回完整结果）
  ///
  /// [prompt] 输入的提示文本
  ///
  /// 返回生成的文本回复
  static Future<String> generate(String prompt) async {
    try {
      final String? result = await _channel.invokeMethod<String>('generate', {
        'prompt': prompt,
      });

      return result ?? '';
    } on PlatformException catch (e) {
      print(
        'LlamaInference.generate PlatformException: ${e.code} - ${e.message}',
      );
      // 如果发生异常，返回空字符串而不是抛出
      return '';
    } catch (e) {
      print('LlamaInference.generate Exception: $e');
      return '';
    }
  }

  /// 流式生成文本回复（异步，逐个字符返回）
  ///
  /// [prompt] 输入的提示文本
  ///
  /// 返回一个 Stream<String>，每个事件是一个 token（字符或字符片段）
  static Stream<String> generateStream(String prompt) {
    // 启动流式生成（不等待完成）
    _channel.invokeMethod('generateStream', {'prompt': prompt}).catchError((e) {
      print('LlamaInference.generateStream 启动失败: $e');
    });

    // 返回 EventChannel 的流
    return _streamChannel
        .receiveBroadcastStream()
        .cast<String?>()
        .where((token) => token != null)
        .cast<String>();
  }

  /// 停止当前正在进行的流式生成
  static Future<void> stopGeneration() async {
    try {
      await _channel.invokeMethod('stopGeneration');
    } on PlatformException catch (e) {
      print(
        'LlamaInference.stopGeneration PlatformException: ${e.code} - ${e.message}',
      );
      rethrow;
    } catch (e) {
      print('LlamaInference.stopGeneration Exception: $e');
      rethrow;
    }
  }

  /// 卸载模型，释放资源
  static Future<void> unloadModel() async {
    try {
      await _channel.invokeMethod('unloadModel');
    } on PlatformException catch (e) {
      print(
        'LlamaInference.unloadModel PlatformException: ${e.code} - ${e.message}',
      );
      rethrow;
    } catch (e) {
      print('LlamaInference.unloadModel Exception: $e');
      rethrow;
    }
  }

  /// 获取默认模型路径
  ///
  /// 使用内部私有目录（getApplicationDocumentsDirectory），确保：
  /// 1. 支持 Direct I/O（避免 FUSE 文件系统的限制）
  /// 2. 无需存储权限
  /// 3. 文件不会被 Android 系统自动清理
  ///
  /// Android 路径示例: `/data/user/0/flyer.chat.flyer_chat/app_flutter/models/qwen2_5_3b.Q4_K_M.gguf`
  /// 其他平台: `${应用程序文档目录}/models/qwen2_5_3b.Q4_K_M.gguf`
  static Future<String> _getDefaultModelPath() async {
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String modelPath = '${appDocDir.path}/models/$_defaultModelName';
      return modelPath;
    } catch (e) {
      print('LlamaInference._getDefaultModelPath Exception: $e');
      rethrow;
    }
  }

  /// 检查模型文件是否存在
  ///
  /// [modelPath] 模型文件路径，如果为 null 则使用默认路径
  ///
  /// 返回 true 表示文件存在，false 表示不存在
  static Future<bool> checkModelExists({String? modelPath}) async {
    try {
      String path = modelPath ?? await _getDefaultModelPath();
      final File modelFile = File(path);
      return await modelFile.exists();
    } catch (e) {
      print('LlamaInference.checkModelExists Exception: $e');
      return false;
    }
  }

  /// 获取模型文件路径（默认路径）
  static Future<String> getModelPath() async {
    return await _getDefaultModelPath();
  }
}

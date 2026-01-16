import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Vosk 离线语音识别包装类
class VoskSpeechRecognition {
  static const MethodChannel _channel = MethodChannel(
    'flyer.chat.flyer_chat/vosk_speech',
  );

  /// 识别结果回调
  final Function(String text, bool isFinal)? onResult;

  /// 部分结果回调（实时识别）
  final Function(String text)? onPartialResult;

  VoskSpeechRecognition({this.onResult, this.onPartialResult}) {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    debugPrint('📞 VoskSpeechRecognition._handleMethodCall: method=${call.method}, arguments=${call.arguments}');
    switch (call.method) {
      case 'onResult':
        final text = call.arguments['text'] as String? ?? '';
        final isFinal = call.arguments['isFinal'] as bool? ?? true;
        debugPrint('📞 onResult 回调: text="$text", isFinal=$isFinal');
        onResult?.call(text, isFinal);
        break;
      case 'onPartialResult':
        final text = call.arguments['text'] as String? ?? '';
        debugPrint('📞 onPartialResult 回调: text="$text"');
        onPartialResult?.call(text);
        break;
      default:
        debugPrint('⚠️ 未知的 method call: ${call.method}');
    }
  }

  /// 初始化 Vosk 模型
  /// [modelPath] 模型路径，如果为 null 则使用默认路径
  Future<bool> initialize({String? modelPath}) async {
    try {
      final result = await _channel.invokeMethod<bool>('initialize', {
        'modelPath': modelPath,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      // 打印详细错误信息以便调试
      print('Vosk initialization error: ${e.code} - ${e.message}');
      print('Details: ${e.details}');
      throw Exception(
        'Failed to initialize Vosk: ${e.code} - ${e.message ?? e.details}',
      );
    } catch (e) {
      print('Vosk initialization exception: $e');
      rethrow;
    }
  }

  /// 开始语音识别
  Future<bool> startListening() async {
    try {
      final result = await _channel.invokeMethod<bool>('startListening');
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to start listening: ${e.message}');
    }
  }

  /// 停止语音识别并获取最终结果
  Future<bool> stopListening() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopListening');
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to stop listening: ${e.message}');
    }
  }

  /// 取消语音识别
  Future<bool> cancel() async {
    try {
      final result = await _channel.invokeMethod<bool>('cancel');
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to cancel: ${e.message}');
    }
  }
}

import 'package:flutter/services.dart';

/// 翻译服务桥接类，用于与 Android 原生侧通信
class TranslateService {
  static const MethodChannel _channel = MethodChannel('flyer.chat.flyer_chat/translate');

  /// 检查无障碍服务是否已启用
  static Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAccessibilityServiceEnabled');
      return result ?? false;
    } catch (e) {
      print('检查无障碍服务状态失败: $e');
      return false;
    }
  }

  /// 检查悬浮窗权限是否已授予
  static Future<bool> canDrawOverlays() async {
    try {
      final result = await _channel.invokeMethod<bool>('canDrawOverlays');
      return result ?? false;
    } catch (e) {
      print('检查悬浮窗权限失败: $e');
      return false;
    }
  }

  /// 打开无障碍设置页面
  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      print('打开无障碍设置失败: $e');
    }
  }

  /// 打开悬浮窗权限设置页面
  static Future<void> openOverlayPermissionSettings() async {
    try {
      await _channel.invokeMethod('openOverlayPermissionSettings');
    } catch (e) {
      print('打开悬浮窗权限设置失败: $e');
    }
  }

  /// 设置翻译服务启用状态（通知原生侧）
  static Future<void> setServiceEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setServiceEnabled', {'enabled': enabled});
    } catch (e) {
      print('设置服务状态失败: $e');
    }
  }
}


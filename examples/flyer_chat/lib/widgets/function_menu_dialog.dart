import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 功能菜单弹窗
///
/// 提供截屏、翻译、通知中心等快捷功能
class FunctionMenuDialog extends StatelessWidget {
  const FunctionMenuDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '快捷功能',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 功能网格
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _FunctionItem(
                  icon: Icons.screenshot,
                  label: '截屏',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.of(context).pop();
                    _takeScreenshot(context);
                  },
                ),
                _FunctionItem(
                  icon: Icons.translate,
                  label: '翻译',
                  color: Colors.green,
                  onTap: () {
                    Navigator.of(context).pop();
                    _openTranslate(context);
                  },
                ),
                _FunctionItem(
                  icon: Icons.notifications,
                  label: '通知中心',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.of(context).pop();
                    _openNotificationCenter(context);
                  },
                ),
                _FunctionItem(
                  icon: Icons.lock,
                  label: '锁屏',
                  color: Colors.red,
                  onTap: () {
                    Navigator.of(context).pop();
                    _lockScreen(context);
                  },
                ),
                _FunctionItem(
                  icon: Icons.settings,
                  label: '设置',
                  color: Colors.grey,
                  onTap: () {
                    Navigator.of(context).pop();
                    _openSettings(context);
                  },
                ),
                _FunctionItem(
                  icon: Icons.brightness_6,
                  label: '亮度',
                  color: Colors.amber,
                  onTap: () {
                    Navigator.of(context).pop();
                    _adjustBrightness(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 截屏
  static Future<void> _takeScreenshot(BuildContext context) async {
    try {
      const platform = MethodChannel('flyer.chat.flyer_chat/system_actions');

      // 检查无障碍服务是否启用
      final isEnabled =
          await platform.invokeMethod<bool>('isAccessibilityServiceEnabled') ??
          false;

      if (!isEnabled) {
        _showAccessibilityRequiredDialog(context, '截屏');
        return;
      }

      await platform.invokeMethod('takeScreenshot');

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('截屏已保存')));
      }
    } catch (e) {
      debugPrint('截屏失败: $e');
      if (context.mounted) {
        if (e is PlatformException && e.code == 'ACCESSIBILITY_NOT_ENABLED') {
          _showAccessibilityRequiredDialog(context, '截屏');
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('截屏失败: $e')));
        }
      }
    }
  }

  /// 打开翻译
  static void _openTranslate(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('翻译功能开发中...')));
  }

  /// 打开通知中心
  static Future<void> _openNotificationCenter(BuildContext context) async {
    try {
      const platform = MethodChannel('flyer.chat.flyer_chat/system_actions');

      // 检查无障碍服务是否启用
      final isEnabled =
          await platform.invokeMethod<bool>('isAccessibilityServiceEnabled') ??
          false;

      if (!isEnabled) {
        _showAccessibilityRequiredDialog(context, '打开通知中心');
        return;
      }

      await platform.invokeMethod('openNotificationPanel');
    } catch (e) {
      debugPrint('打开通知中心失败: $e');
      if (context.mounted) {
        if (e is PlatformException && e.code == 'ACCESSIBILITY_NOT_ENABLED') {
          _showAccessibilityRequiredDialog(context, '打开通知中心');
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('打开通知中心失败: $e')));
        }
      }
    }
  }

  /// 锁屏
  static Future<void> _lockScreen(BuildContext context) async {
    try {
      const platform = MethodChannel('flyer.chat.flyer_chat/system_actions');

      // 检查无障碍服务是否启用
      final isEnabled =
          await platform.invokeMethod<bool>('isAccessibilityServiceEnabled') ??
          false;

      if (!isEnabled) {
        _showAccessibilityRequiredDialog(context, '锁屏');
        return;
      }

      await platform.invokeMethod('lockScreen');
    } catch (e) {
      debugPrint('锁屏失败: $e');
      if (context.mounted) {
        if (e is PlatformException && e.code == 'ACCESSIBILITY_NOT_ENABLED') {
          _showAccessibilityRequiredDialog(context, '锁屏');
        } else if (e is PlatformException && e.code == 'NOT_SUPPORTED') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('锁屏功能需要 Android 9.0 及以上版本')),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('锁屏失败: $e')));
        }
      }
    }
  }

  /// 打开设置
  static Future<void> _openSettings(BuildContext context) async {
    try {
      const platform = MethodChannel('flyer.chat.flyer_chat/system_actions');
      await platform.invokeMethod('openAppSettings');
    } catch (e) {
      debugPrint('打开应用设置失败: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('打开应用设置失败: $e')));
      }
    }
  }

  /// 调整亮度
  static void _adjustBrightness(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('亮度调整功能开发中...')));
  }

  /// 显示无障碍服务必需的对话框，包含详细操作路径
  static void _showAccessibilityRequiredDialog(
    BuildContext context,
    String functionName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要开启无障碍服务'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '使用"$functionName"功能需要开启无障碍服务权限。',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                '开启步骤：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('1. 点击下方"前往设置"按钮'),
              const Text('2. 在无障碍设置页面找到"EchoAI"'),
              const Text('3. 点击进入并开启服务开关'),
              const Text('4. 确认允许权限请求'),
              const SizedBox(height: 16),
              const Text(
                '注意：此权限仅用于执行您主动触发的系统功能，不会记录或上传任何内容。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                const platform = MethodChannel(
                  'flyer.chat.flyer_chat/system_actions',
                );
                await platform.invokeMethod('openAccessibilitySettings');
              } catch (e) {
                debugPrint('打开无障碍设置失败: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('打开设置失败: $e')));
                }
              }
            },
            child: const Text('前往设置'),
          ),
        ],
      ),
    );
  }
}

/// 功能菜单项
class _FunctionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FunctionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

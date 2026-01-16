import 'package:flutter/material.dart';

/// 翻译悬浮窗组件
/// 显示在文本选中位置，提供翻译、复制等功能
class TranslationOverlay extends StatelessWidget {
  /// 选中的文本
  final String selectedText;
  
  /// 翻译结果（可选，初始为 null）
  final String? translation;
  
  /// 是否显示翻译结果
  final bool showTranslation;
  
  /// 复制按钮回调
  final VoidCallback onCopy;
  
  /// 翻译按钮回调
  final VoidCallback onTranslate;
  
  /// 关闭按钮回调
  final VoidCallback onClose;
  
  /// 悬浮窗位置
  final Offset position;

  const TranslationOverlay({
    super.key,
    required this.selectedText,
    this.translation,
    this.showTranslation = false,
    required this.onCopy,
    required this.onTranslate,
    required this.onClose,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 原文
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                selectedText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
            
            // 翻译结果（初始隐藏）
            if (showTranslation && translation != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  translation!,
                  style: const TextStyle(
                    color: Color(0xFF87CEEB), // 浅蓝色
                    fontSize: 16,
                  ),
                ),
              ),
            
            // 分隔线
            const Divider(
              color: Colors.white30,
              height: 1,
              thickness: 1,
            ),
            
            // 按钮行
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 复制按钮
                  TextButton(
                    onPressed: onCopy,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.green.withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '复制',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 4),
                  
                  // 翻译按钮
                  TextButton(
                    onPressed: onTranslate,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.blue.withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '翻译',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 4),
                  
                  // 关闭按钮
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


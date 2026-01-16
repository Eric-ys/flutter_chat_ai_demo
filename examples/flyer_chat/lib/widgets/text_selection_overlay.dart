import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 文本选择悬浮窗管理器
class TextSelectionOverlayManager {
  static OverlayEntry? _overlayEntry;
  static Timer? _autoHideTimer;

  /// 显示文本选择悬浮窗
  static void show({
    required BuildContext context,
    required String selectedText,
    required Offset position,
    required VoidCallback onDismiss,
  }) {
    // 先隐藏之前的悬浮窗
    hide();

    // 取消之前的自动隐藏计时器
    _autoHideTimer?.cancel();

    // 创建悬浮窗
    _overlayEntry = OverlayEntry(
      builder: (context) => _TextSelectionOverlayWidget(
        selectedText: selectedText,
        position: position,
        onDismiss: () {
          hide();
          onDismiss();
        },
      ),
    );

    // 插入到 Overlay
    Overlay.of(context).insert(_overlayEntry!);

    // 5秒后自动隐藏
    _autoHideTimer = Timer(const Duration(seconds: 5), () {
      hide();
    });
  }

  /// 隐藏悬浮窗
  static void hide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

/// 文本选择悬浮窗 Widget
class _TextSelectionOverlayWidget extends StatefulWidget {
  final String selectedText;
  final Offset position;
  final VoidCallback onDismiss;

  const _TextSelectionOverlayWidget({
    required this.selectedText,
    required this.position,
    required this.onDismiss,
  });

  @override
  State<_TextSelectionOverlayWidget> createState() =>
      _TextSelectionOverlayWidgetState();
}

class _TextSelectionOverlayWidgetState
    extends State<_TextSelectionOverlayWidget> {
  String? _translation;
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
    // 加载词典
    _loadDictionary();
  }

  /// 加载离线词典
  Future<void> _loadDictionary() async {
    // 词典在翻译时按需加载，这里不需要预加载
  }

  /// 翻译文本
  Future<void> _translate() async {
    if (_isTranslating || _translation != null) return;

    setState(() {
      _isTranslating = true;
    });

    try {
      // 检查是否为英文文本
      if (!_isEnglishText(widget.selectedText)) {
        setState(() {
          _translation = '非英文文本';
          _isTranslating = false;
        });
        return;
      }

      // 加载词典并查询
      final manifestContent = await rootBundle.loadString(
        'assets/dict_en_zh.json',
      );
      final Map<String, dynamic> dict =
          json.decode(manifestContent) as Map<String, dynamic>;

      // 转小写并查询
      final key = widget.selectedText.toLowerCase().trim();
      final translation = dict[key] as String?;

      setState(() {
        _translation = translation ?? '未收录';
        _isTranslating = false;
      });
    } catch (e) {
      setState(() {
        _translation = '翻译失败';
        _isTranslating = false;
      });
      debugPrint('翻译失败: $e');
    }
  }

  /// 检查是否为英文文本（英文字符占比 ≥ 70%）
  bool _isEnglishText(String text) {
    if (text.isEmpty || text.length < 2) return false;

    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return false;

    // 排除 URL
    if (trimmedText.contains(RegExp(r'https?://|www\.|\.com|\.org|\.net|\.io',
            caseSensitive: false))) {
      return false;
    }

    // 计算英文字符数
    var englishCharCount = 0;
    var totalLetterCount = 0;

    for (final char in trimmedText.runes) {
      if ((char >= 65 && char <= 90) || (char >= 97 && char <= 122)) {
        // ASCII 字母
        englishCharCount++;
        totalLetterCount++;
      } else if ((char >= 0x4E00 && char <= 0x9FFF) ||
          (char >= 0x3400 && char <= 0x4DBF)) {
        // 中文字符
        totalLetterCount++;
      } else if (String.fromCharCode(char).contains(RegExp(r'[a-zA-Z]'))) {
        englishCharCount++;
        totalLetterCount++;
      }
    }

    if (totalLetterCount == 0) return false;

    final englishRatio = englishCharCount / totalLetterCount;
    return englishRatio >= 0.7;
  }

  /// 复制文本到剪贴板
  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.selectedText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制到剪贴板'),
        duration: Duration(seconds: 1),
      ),
    );
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // 计算悬浮窗位置（确保不超出屏幕）
    double x = widget.position.dx;
    double y = widget.position.dy - 80; // 在选中位置上方显示

    // 限制在屏幕范围内
    if (x < 16) x = 16;
    if (x > screenWidth - 320) x = screenWidth - 320;
    if (y < 16) y = 16;
    if (y > screenHeight - 200) y = screenHeight - 200;

    return Stack(
      children: [
        // 全屏透明层，用于检测点击外部区域
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),
        ),
        // 悬浮窗
        Positioned(
          left: x,
          top: y,
          child: GestureDetector(
            onTap: () {
              // 点击悬浮窗本身不关闭
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
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
                padding: const EdgeInsets.all(12),
                child: Text(
                  widget.selectedText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
              // 翻译结果（初始隐藏，点击翻译后显示）
              if (_translation != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Text(
                    _translation!,
                    style: const TextStyle(
                      color: Color(0xFF87CEEB), // 浅蓝色
                      fontSize: 16,
                    ),
                  ),
                ),
              // 按钮行
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 复制按钮
                    _ActionButton(
                      label: '复制',
                      onTap: _copyToClipboard,
                      color: Colors.green.withOpacity(0.3),
                    ),
                    const SizedBox(width: 8),
                    // 翻译按钮
                    _ActionButton(
                      label: _isTranslating ? '翻译中...' : '翻译',
                      onTap: _translate,
                      color: Colors.blue.withOpacity(0.3),
                      isLoading: _isTranslating,
                    ),
                    const SizedBox(width: 8),
                    // 关闭按钮
                    _ActionButton(
                      label: '×',
                      onTap: widget.onDismiss,
                      color: Colors.transparent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 操作按钮
class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool isLoading;

  const _ActionButton({
    required this.label,
    required this.onTap,
    required this.color,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }
}


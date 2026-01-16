import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 可拖拽的文本选择悬浮窗管理器
class DraggableTextOverlay {
  static OverlayEntry? _overlayEntry;
  static Timer? _autoHideTimer;
  static VoidCallback? _onDismissCallback;

  /// 显示可拖拽的文本选择悬浮窗
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

    // 保存回调
    _onDismissCallback = onDismiss;

    // 创建悬浮窗
    _overlayEntry = OverlayEntry(
      builder: (context) => _DraggableTextOverlayWidget(
        selectedText: selectedText,
        initialPosition: position,
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
    _onDismissCallback?.call();
    _onDismissCallback = null;
  }
}

/// 可拖拽的文本选择悬浮窗 Widget
class _DraggableTextOverlayWidget extends StatefulWidget {
  final String selectedText;
  final Offset initialPosition;
  final VoidCallback onDismiss;

  const _DraggableTextOverlayWidget({
    required this.selectedText,
    required this.initialPosition,
    required this.onDismiss,
  });

  @override
  State<_DraggableTextOverlayWidget> createState() =>
      _DraggableTextOverlayWidgetState();
}

class _DraggableTextOverlayWidgetState
    extends State<_DraggableTextOverlayWidget> {
  late Offset _position;
  String? _translation;
  bool _isTranslating = false;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    // 初始化位置，确保在屏幕内
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final screenSize = MediaQuery.of(context).size;
      const widgetWidth = 280.0;
      const widgetHeight = 200.0;
      
      setState(() {
        _position = Offset(
          widget.initialPosition.dx.clamp(0.0, screenSize.width - widgetWidth),
          widget.initialPosition.dy.clamp(0.0, screenSize.height - widgetHeight),
        );
      });
    });
    _position = widget.initialPosition;
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

  /// 吸附到边缘（参考苹果辅助按钮的吸附逻辑）
  Offset _snapToEdge(Offset position, Size screenSize, Size widgetSize) {
    const snapThreshold = 60.0; // 吸附阈值
    double x = position.dx;
    double y = position.dy;

    // 水平方向吸附
    if (x < snapThreshold) {
      x = 0; // 吸附到左边缘
    } else if (x > screenSize.width - widgetSize.width - snapThreshold) {
      x = screenSize.width - widgetSize.width; // 吸附到右边缘
    }

    // 垂直方向吸附
    if (y < snapThreshold) {
      y = 0; // 吸附到顶部
    } else if (y > screenSize.height - widgetSize.height - snapThreshold) {
      y = screenSize.height - widgetSize.height; // 吸附到底部
    }

    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const widgetWidth = 280.0;
    const widgetHeight = 200.0;

    // 确保位置在屏幕内
    double x = _position.dx.clamp(0.0, screenSize.width - widgetWidth);
    double y = _position.dy.clamp(0.0, screenSize.height - widgetHeight);

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
        // 可拖拽的悬浮窗
        Positioned(
          left: x,
          top: y,
          child: GestureDetector(
            onPanStart: (details) {
              setState(() {
                _isDragging = true;
              });
            },
            onPanUpdate: (details) {
              setState(() {
                _position = Offset(
                  (_position.dx + details.delta.dx).clamp(
                    0.0,
                    screenSize.width - widgetWidth,
                  ),
                  (_position.dy + details.delta.dy).clamp(
                    0.0,
                    screenSize.height - widgetHeight,
                  ),
                );
              });
            },
            onPanEnd: (details) {
              setState(() {
                _isDragging = false;
                // 吸附到边缘
                _position = _snapToEdge(
                  _position,
                  screenSize,
                  const Size(widgetWidth, widgetHeight),
                );
              });
            },
            child: Material(
              color: Colors.transparent,
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: widgetWidth,
                constraints: const BoxConstraints(
                  minHeight: widgetHeight,
                  maxHeight: 300,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? CupertinoColors.systemGrey6.darkColor
                      : CupertinoColors.systemBackground.resolveFrom(context),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 拖拽指示器（仅在拖拽时显示）
                    if (_isDragging)
                      Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: CupertinoColors.separator.resolveFrom(context),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    // 原文
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        widget.selectedText,
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? CupertinoColors.white
                              : CupertinoColors.label.resolveFrom(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // 翻译结果（初始隐藏，点击翻译后显示）
                    if (_translation != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text(
                          _translation!,
                          style: TextStyle(
                            color: CupertinoColors.systemBlue.resolveFrom(context),
                            fontSize: 15,
                          ),
                        ),
                      ),
                    // 分隔线
                    Divider(
                      height: 0.5,
                      color: CupertinoColors.separator.resolveFrom(context),
                    ),
                    // 操作按钮（使用 PullDownMenuItem 样式）
                    _ActionButton(
                      title: '复制',
                      icon: CupertinoIcons.doc_on_doc,
                      onTap: _copyToClipboard,
                    ),
                    Divider(
                      height: 0.5,
                      color: CupertinoColors.separator.resolveFrom(context),
                    ),
                    _ActionButton(
                      title: _isTranslating ? '翻译中...' : '翻译',
                      icon: CupertinoIcons.textformat,
                      onTap: _translate,
                      isLoading: _isTranslating,
                    ),
                    Divider(
                      height: 0.5,
                      color: CupertinoColors.separator.resolveFrom(context),
                    ),
                    _ActionButton(
                      title: '关闭',
                      icon: CupertinoIcons.xmark,
                      onTap: widget.onDismiss,
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

/// 操作按钮（参考 PullDownMenuItem 样式）
class _ActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isLoading;

  const _ActionButton({
    required this.title,
    required this.icon,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CupertinoActivityIndicator(
                    radius: 8,
                    color: isDark
                        ? CupertinoColors.white
                        : CupertinoColors.label.resolveFrom(context),
                  ),
                )
              else
                Icon(
                  icon,
                  size: 20,
                  color: isDark
                      ? CupertinoColors.white
                      : CupertinoColors.label.resolveFrom(context),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDark
                        ? CupertinoColors.white
                        : CupertinoColors.label.resolveFrom(context),
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


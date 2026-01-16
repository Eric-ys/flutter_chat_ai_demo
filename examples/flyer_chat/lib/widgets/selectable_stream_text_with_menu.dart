import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flyer_chat_text_stream_message/flyer_chat_text_stream_message.dart';
import 'package:pull_down_button/pull_down_button.dart';

/// 支持文本选择和弹窗的流式文本消息组件
class SelectableStreamTextWithMenu extends StatefulWidget {
  final TextStreamMessage message;
  final int index;
  final StreamState streamState;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;
  final Color? sentBackgroundColor;
  final Color? receivedBackgroundColor;
  final TextStyle? sentTextStyle;
  final TextStyle? receivedTextStyle;
  final TextStyle? timeStyle;
  final bool showTime;
  final bool showStatus;
  final TimeAndStatusPosition timeAndStatusPosition;
  final Duration chunkAnimationDuration;
  final TextStreamMessageMode mode;
  final void Function(String url, String title)? onLinkTap;
  final Color? sentLinksColor;
  final Color? receivedLinksColor;
  final Color? sentLinksDecorationColor;
  final Color? receivedLinksDecorationColor;
  final TextDecoration? linksDecoration;
  final void Function(TextStreamMessage message)? onDelete;

  const SelectableStreamTextWithMenu({
    super.key,
    required this.message,
    required this.index,
    required this.streamState,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.borderRadius,
    this.sentBackgroundColor,
    this.receivedBackgroundColor,
    this.sentTextStyle,
    this.receivedTextStyle,
    this.timeStyle,
    this.showTime = true,
    this.showStatus = true,
    this.timeAndStatusPosition = TimeAndStatusPosition.end,
    this.chunkAnimationDuration = const Duration(milliseconds: 100),
    this.mode = TextStreamMessageMode.instantMarkdown,
    this.onLinkTap,
    this.sentLinksColor,
    this.receivedLinksColor,
    this.sentLinksDecorationColor,
    this.receivedLinksDecorationColor,
    this.linksDecoration,
    this.onDelete,
  });

  @override
  State<SelectableStreamTextWithMenu> createState() =>
      _SelectableStreamTextWithMenuState();
}

class _SelectableStreamTextWithMenuState
    extends State<SelectableStreamTextWithMenu> {
  final GlobalKey _messageKey = GlobalKey();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _showMenuTimer;

  /// 获取当前显示的文本
  String get _currentText {
    if (widget.streamState is StreamStateStreaming) {
      return (widget.streamState as StreamStateStreaming).accumulatedText;
    } else if (widget.streamState is StreamStateCompleted) {
      return (widget.streamState as StreamStateCompleted).finalText;
    } else if (widget.streamState is StreamStateError) {
      return (widget.streamState as StreamStateError).accumulatedText ?? '';
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _textController.text = _currentText;
    _textController.addListener(_onSelectionChanged);
    // 设置 FocusNode 不唤起键盘
    _focusNode.skipTraversal = true;
    _focusNode.canRequestFocus = true;
    // 监听焦点变化，确保键盘不弹出
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        // 当获得焦点时，立即隐藏键盘
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      }
    });
  }

  @override
  void didUpdateWidget(SelectableStreamTextWithMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 更新文本内容
    final newText = _currentText;
    if (_textController.text != newText) {
      final oldSelection = _textController.selection;
      _textController.text = newText;
      // 保持选择位置（如果文本长度允许）
      if (oldSelection.isValid && oldSelection.end <= newText.length) {
        _textController.selection = oldSelection;
      }
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onSelectionChanged);
    _textController.dispose();
    _focusNode.dispose();
    _showMenuTimer?.cancel();
    super.dispose();
  }

  void _onSelectionChanged() {
    final selection = _textController.selection;

    // 如果有选中文本，延迟显示菜单
    if (selection.isValid && !selection.isCollapsed) {
      _showMenuTimer?.cancel();
      _showMenuTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted && _textController.selection.isValid &&
            !_textController.selection.isCollapsed) {
          _showMenuForSelection();
        }
      });
    } else {
      _showMenuTimer?.cancel();
    }
  }

  Offset? _lastDoubleTapPosition;

  /// 处理双击事件 - 在手离开屏幕时选中单词
  void _handleDoubleTap() {
    if (_lastDoubleTapPosition == null) return;
    
    // 延迟执行，确保手已经离开屏幕
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lastDoubleTapPosition == null) return;
      
      final text = _currentText;
      if (text.isEmpty) {
        _lastDoubleTapPosition = null;
        return;
      }

      final RenderBox? renderBox =
          _messageKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) {
        _lastDoubleTapPosition = null;
        return;
      }

      final localPosition = renderBox.globalToLocal(_lastDoubleTapPosition!);
      final theme = Theme.of(context);
      final textStyle = (widget.sentTextStyle ??
          widget.receivedTextStyle ??
          theme.textTheme.bodyMedium ??
          const TextStyle()).copyWith(
        fontSize: (widget.sentTextStyle ??
                widget.receivedTextStyle ??
                theme.textTheme.bodyMedium)
            ?.fontSize ??
            16,
        height: (widget.sentTextStyle ??
                widget.receivedTextStyle ??
                theme.textTheme.bodyMedium)
            ?.height ??
            1.5,
        letterSpacing: (widget.sentTextStyle ??
                widget.receivedTextStyle ??
                theme.textTheme.bodyMedium)
            ?.letterSpacing ??
            0,
      );

      final textPainter = TextPainter(
        text: TextSpan(text: text, style: textStyle),
        textDirection: TextDirection.ltr,
        maxLines: null,
      );

      final constraints = renderBox.constraints;
      textPainter.layout(maxWidth: constraints.maxWidth);

      final position = textPainter.getPositionForOffset(localPosition);
      final offset = position.offset;

      if (offset < 0 || offset >= text.length) {
        _lastDoubleTapPosition = null;
        return;
      }

      // 找到单词边界（只选择文字和表情）
      int start = offset;
      int end = offset;

      // 向前查找单词开始
      while (start > 0 && _isSelectableChar(text[start - 1])) {
        start--;
      }

      // 向后查找单词结束
      while (end < text.length && _isSelectableChar(text[end])) {
        end++;
      }

      if (start >= end) {
        _lastDoubleTapPosition = null;
        return;
      }

      // 设置文本选择
      _textController.selection = TextSelection(
        baseOffset: start,
        extentOffset: end,
      );

      // 获取焦点以显示选择控件（但不唤起键盘）
      _focusNode.requestFocus();
      
      // 立即隐藏键盘（如果已显示）
      FocusScope.of(context).unfocus();
      
      // 重新获取焦点但不显示键盘
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
          // 再次确保键盘不显示
          SystemChannels.textInput.invokeMethod('TextInput.hide');
        }
      });
      
      _lastDoubleTapPosition = null;
    });
  }

  /// 记录双击位置
  void _handleDoubleTapDown(TapDownDetails details) {
    _lastDoubleTapPosition = details.globalPosition;
  }

  /// 检查是否为可选字符（只允许文字和表情，排除标点符号）
  bool _isSelectableChar(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    // 只支持：
    // - 英文、数字
    // - 中文（包括扩展A）
    // - 表情符号
    // - 连字符和下划线（用于复合词）
    return (code >= 65 && code <= 90) || // A-Z
        (code >= 97 && code <= 122) || // a-z
        (code >= 48 && code <= 57) || // 0-9
        (code >= 0x4E00 && code <= 0x9FFF) || // 中文
        (code >= 0x3400 && code <= 0x4DBF) || // 扩展A
        (code >= 0x1F300 && code <= 0x1F9FF) || // 表情符号
        (code >= 0x1F600 && code <= 0x1F64F) || // 表情符号
        (code >= 0x1F900 && code <= 0x1F9FF) || // 表情符号
        (code >= 0x2600 && code <= 0x26FF) || // 杂项符号
        (code >= 0x2700 && code <= 0x27BF) || // 装饰符号
        code == 45 || // - (连字符，用于复合词)
        code == 95; // _ (下划线)
  }

  /// 显示选中文本的菜单
  void _showMenuForSelection() {
    if (!_textController.selection.isValid ||
        _textController.selection.isCollapsed) return;

    final selectedText = _currentText.substring(
      _textController.selection.start,
      _textController.selection.end,
    );

    if (selectedText.trim().isEmpty) return;

    // 获取选中文本的位置
    final RenderBox? renderBox =
        _messageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final theme = Theme.of(context);
    final textStyle = (widget.sentTextStyle ??
            widget.receivedTextStyle ??
            theme.textTheme.bodyMedium ??
            const TextStyle())
        .copyWith(
      fontSize: (widget.sentTextStyle ??
              widget.receivedTextStyle ??
              theme.textTheme.bodyMedium)
          ?.fontSize ??
          16,
      height: (widget.sentTextStyle ??
              widget.receivedTextStyle ??
              theme.textTheme.bodyMedium)
          ?.height ??
          1.5,
      letterSpacing: (widget.sentTextStyle ??
              widget.receivedTextStyle ??
              theme.textTheme.bodyMedium)
          ?.letterSpacing ??
          0,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: _currentText,
        style: textStyle,
      ),
      textDirection: TextDirection.ltr,
      maxLines: null,
    );
    
    final constraints = renderBox.constraints;
    textPainter.layout(maxWidth: constraints.maxWidth);

    final startOffset = textPainter.getOffsetForCaret(
      TextPosition(offset: _textController.selection.start),
      Rect.zero,
    );
    final endOffset = textPainter.getOffsetForCaret(
      TextPosition(offset: _textController.selection.end),
      Rect.zero,
    );

    final centerX = (startOffset.dx + endOffset.dx) / 2;
    final centerY = (startOffset.dy + endOffset.dy) / 2;
    final localCenter = Offset(centerX, centerY);
    final globalCenter = renderBox.localToGlobal(localCenter);

    _showMenu(globalCenter, selectedText);
  }

  /// 显示操作菜单
  void _showMenu(Offset position, String selectedText) {
    final menuRect = Rect.fromCenter(
      center: position,
      width: 0,
      height: 0,
    );

    final items = [
      PullDownMenuItem(
        title: '复制',
        icon: CupertinoIcons.doc_on_doc,
        onTap: () {
          _copyText(selectedText);
          _clearSelection();
        },
      ),
      PullDownMenuItem(
        title: '翻译',
        icon: CupertinoIcons.textformat,
        onTap: () {
          _translateText(selectedText);
          _clearSelection();
        },
      ),
      if (widget.onDelete != null)
        PullDownMenuItem(
          title: '删除',
          icon: CupertinoIcons.delete,
          isDestructive: true,
          onTap: () {
            widget.onDelete!(widget.message);
            _clearSelection();
          },
        ),
    ];

    showPullDownMenu(
      context: context,
      position: menuRect,
      items: items,
    ).then((_) {
      _clearSelection();
    });
  }

  /// 清除选择
  void _clearSelection() {
    _textController.selection = const TextSelection.collapsed(offset: 0);
    _focusNode.unfocus();
  }

  /// 复制文本
  void _copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已复制: $text')),
    );
  }

  /// 翻译文本（支持中英互译）
  Future<void> _translateText(String text) async {
    try {
      // 加载词典
      final manifestContent = await rootBundle.loadString(
        'assets/dict_en_zh.json',
      );
      final Map<String, dynamic> dict =
          json.decode(manifestContent) as Map<String, dynamic>;

      String? translation;

      // 判断是英文还是中文
      if (_isEnglishText(text)) {
        // 英文 -> 中文
        final key = text.toLowerCase().trim();
        translation = dict[key]?.toString();
      } else if (_isChineseText(text)) {
        // 中文 -> 英文（反向查找）
        for (final entry in dict.entries) {
          final value = entry.value.toString();
          // 检查是否包含中文文本
          final parts = value.split('；');
          for (final part in parts) {
            if (part.trim() == text.trim() || text.contains(part.trim())) {
              translation = entry.key;
              break;
            }
          }
          if (translation != null) break;
        }
      }

      if (!mounted) return;

      if (translation != null && translation.isNotEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(text),
            content: Text(translation!),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到翻译')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('翻译失败: $e')),
      );
      debugPrint('翻译失败: $e');
    }
  }

  /// 检查是否为英文文本
  bool _isEnglishText(String text) {
    if (text.isEmpty) return false;
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return false;

    var englishCharCount = 0;
    var totalCharCount = 0;

    for (final char in trimmedText.runes) {
      totalCharCount++;
      if ((char >= 65 && char <= 90) || (char >= 97 && char <= 122)) {
        englishCharCount++;
      }
    }

    if (totalCharCount == 0) return false;
    return (englishCharCount / totalCharCount) >= 0.5;
  }

  /// 检查是否为中文文本
  bool _isChineseText(String text) {
    if (text.isEmpty) return false;
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return false;

    var chineseCharCount = 0;
    var totalCharCount = 0;

    for (final char in trimmedText.runes) {
      totalCharCount++;
      if ((char >= 0x4E00 && char <= 0x9FFF) ||
          (char >= 0x3400 && char <= 0x4DBF)) {
        chineseCharCount++;
      }
    }

    if (totalCharCount == 0) return false;
    return (chineseCharCount / totalCharCount) >= 0.3;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = widget.sentTextStyle ??
        widget.receivedTextStyle ??
        theme.textTheme.bodyMedium ??
        const TextStyle();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTapDown: _handleDoubleTapDown,
      onDoubleTap: _handleDoubleTap,
      onTap: () {
        // 点击其他位置清除选择
        if (_textController.selection.isValid &&
            !_textController.selection.isCollapsed) {
          _clearSelection();
        }
      },
      child: Container(
        key: _messageKey,
        child: Stack(
          children: [
            // 原始流式消息组件（用于显示）
            FlyerChatTextStreamMessage(
              message: widget.message,
              index: widget.index,
              streamState: widget.streamState,
              padding: widget.padding,
              borderRadius: widget.borderRadius,
              sentBackgroundColor: widget.sentBackgroundColor,
              receivedBackgroundColor: widget.receivedBackgroundColor,
              sentTextStyle: widget.sentTextStyle,
              receivedTextStyle: widget.receivedTextStyle,
              timeStyle: widget.timeStyle,
              showTime: widget.showTime,
              showStatus: widget.showStatus,
              timeAndStatusPosition: widget.timeAndStatusPosition,
              chunkAnimationDuration: widget.chunkAnimationDuration,
              mode: widget.mode,
              onLinkTap: widget.onLinkTap,
              sentLinksColor: widget.sentLinksColor,
              receivedLinksColor: widget.receivedLinksColor,
              sentLinksDecorationColor: widget.sentLinksDecorationColor,
              receivedLinksDecorationColor: widget.receivedLinksDecorationColor,
              linksDecoration: widget.linksDecoration,
            ),
            // TextField 用于文本选择（Android风格，蓝色背景+可拖动光标）
            // 使用绝对定位覆盖在消息上方，实现文本选择功能
            ExcludeSemantics(
              child: IgnorePointer(
                ignoring: false,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    textSelectionTheme: TextSelectionThemeData(
                      selectionColor: Colors.blue.withOpacity(0.3), // 蓝色选中背景
                      selectionHandleColor: Colors.blue, // 蓝色选择手柄
                      cursorColor: Colors.blue, // 蓝色光标
                    ),
                  ),
                  child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  selectionControls: _AndroidStyleSelectionControls(),
                  style: textStyle.copyWith(
                    color: Colors.transparent, // 透明文字，只显示选择效果
                    fontSize: textStyle.fontSize ?? 16,
                    height: textStyle.height ?? 1.5, // 保持行高一致
                    letterSpacing: textStyle.letterSpacing ?? 0, // 保持字间距一致
                  ),
                  maxLines: null,
                  textAlign: TextAlign.start,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  showCursor: false, // 隐藏光标
                  readOnly: true, // 只读，仅用于选择
                  enableInteractiveSelection: true, // 启用交互式选择，允许拖拽调整
                  // 阻止键盘弹出
                  keyboardType: TextInputType.none,
                ),
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Android 风格的文本选择控制器（蓝色背景+可拖动光标）
class _AndroidStyleSelectionControls extends MaterialTextSelectionControls {
  @override
  Widget buildToolbar(
    BuildContext context,
    Rect globalEditableRegion,
    double textLineHeight,
    Offset selectionMidpoint,
    List<TextSelectionPoint> endpoints,
    TextSelectionDelegate delegate,
    ValueListenable<ClipboardStatus>? clipboardStatus,
    Offset? lastSecondaryTapDownPosition,
  ) {
    // 返回空，使用自定义菜单
    return const SizedBox.shrink();
  }

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) {
    // 自定义选择手柄样式（蓝色圆形，可拖动）
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }

  @override
  Size getHandleSize(double textLineHeight) {
    return const Size(20, 20);
  }
}

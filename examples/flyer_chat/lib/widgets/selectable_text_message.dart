import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flyer_chat_text_message/flyer_chat_text_message.dart';
import 'draggable_text_overlay.dart';
import 'custom_text_selection_menu.dart';
import '../services/offline_translator.dart';

/// 支持文本选择的消息组件
/// 包装 FlyerChatTextMessage，添加双击文本选择功能
class SelectableTextMessage extends StatefulWidget {
  final TextMessage message;
  final int index;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;
  final BoxConstraints? constraints;
  final double? onlyEmojiFontSize;
  final Color? sentBackgroundColor;
  final Color? receivedBackgroundColor;
  final TextStyle? sentTextStyle;
  final TextStyle? receivedTextStyle;
  final Color? sentLinksColor;
  final Color? receivedLinksColor;
  final Color? sentLinksDecorationColor;
  final Color? receivedLinksDecorationColor;
  final TextDecoration? linksDecoration;
  final TextStyle? timeStyle;
  final bool showTime;
  final bool showStatus;
  final TimeAndStatusPosition timeAndStatusPosition;
  final EdgeInsetsGeometry? timeAndStatusPositionInlineInsets;
  final void Function(String url, String title)? onLinkTap;
  final LinkPreviewPosition linkPreviewPosition;
  final Widget? topWidget;

  const SelectableTextMessage({
    super.key,
    required this.message,
    required this.index,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.borderRadius,
    this.constraints,
    this.onlyEmojiFontSize = 48,
    this.sentBackgroundColor,
    this.receivedBackgroundColor,
    this.sentTextStyle,
    this.receivedTextStyle,
    this.sentLinksColor,
    this.receivedLinksColor,
    this.sentLinksDecorationColor,
    this.receivedLinksDecorationColor,
    this.linksDecoration,
    this.timeStyle,
    this.showTime = true,
    this.showStatus = true,
    this.timeAndStatusPosition = TimeAndStatusPosition.end,
    this.timeAndStatusPositionInlineInsets = const EdgeInsets.only(bottom: 2),
    this.onLinkTap,
    this.linkPreviewPosition = LinkPreviewPosition.bottom,
    this.topWidget,
  });

  @override
  State<SelectableTextMessage> createState() => _SelectableTextMessageState();
}

class _SelectableTextMessageState extends State<SelectableTextMessage> {
  final GlobalKey _messageKey = GlobalKey();
  String? _selectedWord;

  @override
  void dispose() {
    DraggableTextOverlay.hide();
    super.dispose();
  }

  /// 处理双击事件
  void _handleDoubleTap(TapDownDetails details) {
    // 获取消息文本
    final text = widget.message.text;
    if (text.isEmpty) return;

    // 延迟执行，确保渲染完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 获取文本渲染框
      final RenderBox? renderBox =
          _messageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

      // 将全局坐标转换为本地坐标
      final localPosition = renderBox.globalToLocal(details.globalPosition);

      // 获取文本样式（从主题中获取）
      final theme = Theme.of(context);
      final textStyle = widget.sentTextStyle ??
          widget.receivedTextStyle ??
          theme.textTheme.bodyMedium ??
          const TextStyle();

      // 使用 TextPainter 找到点击位置的单词
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: textStyle,
        ),
      textDirection: TextDirection.ltr,
      maxLines: null,
    );

      // 获取容器的宽度约束
      final constraints = renderBox.constraints;
      textPainter.layout(maxWidth: constraints.maxWidth);

      // 找到点击位置的字符索引
      final position = textPainter.getPositionForOffset(localPosition);
      final offset = position.offset;

      if (offset < 0 || offset >= text.length) return;

      // 找到单词边界（支持英文单词）
      int start = offset;
      int end = offset;

      // 向前查找单词开始
      while (start > 0 && _isWordChar(text[start - 1])) {
        start--;
      }

      // 向后查找单词结束
      while (end < text.length && _isWordChar(text[end])) {
        end++;
      }

      if (start >= end) return;

      // 获取选中的单词
      final selectedWord = text.substring(start, end).trim();
      if (selectedWord.isEmpty || selectedWord.length < 2) return;

      // 计算选中文本的显示位置
    final startOffset = textPainter.getOffsetForCaret(
        TextPosition(offset: start),
      Rect.zero,
    );
    final endOffset = textPainter.getOffsetForCaret(
        TextPosition(offset: end),
      Rect.zero,
    );

      // 计算选中文本的中心位置（全局坐标）
    final centerX = (startOffset.dx + endOffset.dx) / 2;
    final centerY = (startOffset.dy + endOffset.dy) / 2;
      final localCenter = Offset(centerX, centerY);
      final globalCenter = renderBox.localToGlobal(localCenter);

      // 保存选择信息
      if (mounted) {
        setState(() {
          _selectedWord = selectedWord;
        });

        // 显示可拖拽悬浮窗
        DraggableTextOverlay.show(
          context: context,
          selectedText: selectedWord,
          position: globalCenter,
          onDismiss: () {
            if (mounted) {
              setState(() {
                _selectedWord = null;
              });
            }
          },
        );
      }
    });
  }

  /// 检查是否为单词字符（字母、数字、连字符、下划线）
  bool _isWordChar(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return (code >= 65 && code <= 90) || // A-Z
        (code >= 97 && code <= 122) || // a-z
        (code >= 48 && code <= 57) || // 0-9
        code == 45 || // -
        code == 95; // _
  }

  /// 处理单击事件（点击其他位置关闭悬浮窗）
  void _handleTapDown(TapDownDetails details) {
    if (_selectedWord != null) {
      // 点击其他位置，关闭悬浮窗（悬浮窗内部会处理点击事件）
      DraggableTextOverlay.hide();
    setState(() {
        _selectedWord = null;
    });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      contextMenuBuilder: (context, state) {
        // 保存 context 的引用，确保在异步操作中可以使用
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        final mountedContext = context;
        
        return CustomTextSelectionMenu(
          state: state,
          onTranslate: (text) {
            // 处理翻译功能，使用保存的 context
            _handleTranslate(mountedContext, scaffoldMessenger, text);
          },
        );
      },
      child: GestureDetector(
        onDoubleTapDown: _handleDoubleTap,
        onTapDown: _handleTapDown,
        child: Container(
          key: _messageKey,
          child: FlyerChatTextMessage(
              message: widget.message,
              index: widget.index,
              padding: widget.padding,
              borderRadius: widget.borderRadius,
              constraints: widget.constraints,
              onlyEmojiFontSize: widget.onlyEmojiFontSize,
              sentBackgroundColor: widget.sentBackgroundColor,
              receivedBackgroundColor: widget.receivedBackgroundColor,
              sentTextStyle: widget.sentTextStyle,
              receivedTextStyle: widget.receivedTextStyle,
              sentLinksColor: widget.sentLinksColor,
              receivedLinksColor: widget.receivedLinksColor,
              sentLinksDecorationColor: widget.sentLinksDecorationColor,
              receivedLinksDecorationColor: widget.receivedLinksDecorationColor,
              linksDecoration: widget.linksDecoration,
              timeStyle: widget.timeStyle,
              showTime: widget.showTime,
              showStatus: widget.showStatus,
              timeAndStatusPosition: widget.timeAndStatusPosition,
              timeAndStatusPositionInlineInsets: widget.timeAndStatusPositionInlineInsets,
              onLinkTap: widget.onLinkTap,
              linkPreviewPosition: widget.linkPreviewPosition,
              topWidget: widget.topWidget,
            ),
        ),
      ),
    );
  }

  /// 处理翻译功能（支持中英互译）
  Future<void> _handleTranslate(
    BuildContext context,
    ScaffoldMessengerState scaffoldMessenger,
    String text,
  ) async {
    debugPrint('🌐 开始翻译: "$text"');
    
    if (text.trim().isEmpty) {
      debugPrint('⚠️ 文本为空');
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('未选中文本'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    try {
      // 获取翻译服务
      debugPrint('🔍 获取翻译服务...');
      final translator = await _getTranslator();
      if (translator == null) {
        debugPrint('❌ 翻译服务不可用');
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('翻译服务不可用'),
            duration: Duration(seconds: 1),
          ),
        );
        return;
      }

      // 初始化翻译服务
      debugPrint('🔄 初始化翻译服务...');
      final initialized = await translator.initialize();
      if (!initialized) {
        debugPrint('❌ 翻译服务初始化失败');
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('翻译服务初始化失败'),
            duration: Duration(seconds: 1),
          ),
        );
        return;
      }
      
      debugPrint('✅ 翻译服务初始化成功');

      // 检测文本语言并翻译
      final trimmedText = text.trim();
      final hasChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(trimmedText);
      final isEnglish = translator.isEnglishText(trimmedText);
      
      String? translated;
      String direction;
      
      if (hasChinese) {
        // 中文 -> 英文
        direction = '中译英';
        translated = translator.translateZhToEnSmart(trimmedText);
        // 如果智能翻译失败，尝试精确匹配
        if (translated == null) {
          translated = translator.translateZhToEn(trimmedText);
        }
      } else if (isEnglish) {
        // 英文 -> 中文
        direction = '英译中';
        translated = translator.translate(trimmedText);
      } else {
        // 无法确定语言，尝试自动翻译
        direction = '自动翻译';
        translated = translator.translateAuto(trimmedText);
      }

      debugPrint('🌐 翻译结果: direction=$direction, translated=$translated');
      
      // 显示翻译结果（使用传入的 scaffoldMessenger，避免 context unmount 问题）
      if (translated != null && translated.isNotEmpty && translated != trimmedText) {
          debugPrint('✅ 显示翻译结果');
          // 有翻译结果
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$direction:',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    translated,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
              action: SnackBarAction(
                label: '复制',
                textColor: Colors.white,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: translated ?? ''));
                  scaffoldMessenger.hideCurrentSnackBar();
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('已复制翻译结果'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ),
          );
        } else {
          debugPrint('⚠️ 未找到翻译结果');
          // 未找到翻译
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('未找到 "$trimmedText" 的翻译'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
            ),
          );
        }
    } catch (e, stackTrace) {
      debugPrint('❌ 翻译失败: $e');
      debugPrint('堆栈跟踪: $stackTrace');
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('翻译失败: ${e.toString()}'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
        ),
      );
    }
  }

  /// 获取翻译服务（如果可用）
  Future<OfflineTranslator?> _getTranslator() async {
    try {
      return OfflineTranslator.instance;
    } catch (e) {
      return null;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:provider/provider.dart';
import 'package:flyer_chat_text_stream_message/flyer_chat_text_stream_message.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'android_selection_toolbar.dart';

/// Flutter 渲染的可选中流式文本消息（不使用任何原生 PlatformView）
class NativeChatTextStreamMessage extends StatefulWidget {
  final TextStreamMessage message;
  final int index;
  final StreamState streamState;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;
  final Color? sentBackgroundColor;
  final Color? receivedBackgroundColor;
  final TextStyle? sentTextStyle;
  final TextStyle? receivedTextStyle;
  final double? textSize;
  final String? textColor;
  final void Function(TextStreamMessage message)? onDelete;
  final void Function(String url, String title)? onLinkTap;

  const NativeChatTextStreamMessage({
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
    this.textSize,
    this.textColor,
    this.onDelete,
    this.onLinkTap,
  });

  @override
  State<NativeChatTextStreamMessage> createState() =>
      _NativeChatTextStreamMessageState();
}

class _NativeChatTextStreamMessageState
    extends State<NativeChatTextStreamMessage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(NativeChatTextStreamMessage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Streaming 阶段使用 Flutter 富文本渲染，无需与原生同步
  }

  /// 获取当前显示的文本
  String _getCurrentText() {
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
  Widget build(BuildContext context) {
    super.build(context); // 必须调用以支持 AutomaticKeepAliveClientMixin
    final isSentByMe = context.read<UserID>() == widget.message.authorId;

    // 确定背景颜色
    final backgroundColor = isSentByMe
        ? (widget.sentBackgroundColor ?? Colors.blue.shade100)
        : (widget.receivedBackgroundColor ?? Colors.grey.shade200);

    // 确定文本样式
    final textStyle = isSentByMe
        ? widget.sentTextStyle
        : widget.receivedTextStyle;
    final finalTextSize = widget.textSize ?? textStyle?.fontSize ?? 16.0;
    final finalTextColor =
        widget.textColor ??
        (textStyle?.color != null
            ? '#${textStyle!.color!.value.toRadixString(16).padLeft(8, '0').substring(2)}'
            : null);

    // 始终启用文本选择功能
    // 注意：ChatMessage 组件已修复，当 onMessageLongPress 为 null 时不会拦截长按事件
    // SelectionArea 现在应该能够正常处理长按手势来选择文本
    final content = Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          textSelectionTheme: const TextSelectionThemeData(
            selectionColor: Color(0x337F7F7F), // #7F7F7F @ 0.2
            selectionHandleColor: Color(0xFF007AFF), // #007AFF
          ),
        ),
        child: SelectionArea(
          contextMenuBuilder: (context, state) =>
              AndroidSelectionToolbar(state: state),
          child: _buildBody(
            isAndroid: false,
            textStyle: textStyle,
            finalTextSize: finalTextSize,
            finalTextColor: finalTextColor,
          ),
        ),
      ),
    );

    return content;
  }

  Widget _buildBody({
    required bool isAndroid,
    required TextStyle? textStyle,
    required double finalTextSize,
    required String? finalTextColor,
  }) {
    final text = _getCurrentText();
    if (text.isEmpty) {
      return Text(
        '...',
        style: TextStyle(fontSize: finalTextSize, color: textStyle?.color),
      );
    }

    // ✅ 关键：流式阶段用 Flutter 富文本渲染（不会出现 PlatformView resize 的文字"拉伸/抖动"）
    // 注意：当被 SelectionArea 包裹时，不要使用 RepaintBoundary，否则可能影响文本选择功能
    return GptMarkdown(
      text,
      style: TextStyle(fontSize: finalTextSize, color: textStyle?.color),
      onLinkTap: widget.onLinkTap,
    );
  }
}

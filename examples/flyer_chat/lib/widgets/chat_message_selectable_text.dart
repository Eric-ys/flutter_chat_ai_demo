import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 聊天消息可选中文本组件
/// 
/// 提供与 Android 原生系统一致的文本选中交互体验：
/// - 双击单词自动选中整个单词（支持富文本）
/// - 长按或拖动可自定义选择范围
/// - 显示两个可拖动的光标手柄（蓝色小水滴样式）
/// - 支持复制、全选等标准操作
/// - 选中状态在菜单操作后保持，直到用户点击空白处
/// 
/// ⚠️ **重要限制**：
/// - 富文本必须使用 `TextSpan` + 样式，**禁止使用 `WidgetSpan`**
/// - 表情应使用 Unicode 字符（如 😀），而非 `WidgetSpan` 包裹的图片
/// - `WidgetSpan` 会破坏文本连续性，导致选区计算错误和双击失效
/// 
/// 示例用法：
/// ```dart
/// ChatMessageSelectableText(
///   message: 'Hello, double-tap to select this word!',
///   style: TextStyle(fontSize: 16),
/// )
/// ```
class ChatMessageSelectableText extends StatefulWidget {
  /// 要显示的文本消息
  final String message;

  /// 文本样式
  final TextStyle? style;

  /// 文本对齐方式
  final TextAlign textAlign;

  /// 文本方向
  final TextDirection? textDirection;

  /// 最大行数，null 表示不限制
  final int? maxLines;

  /// 选择改变时的回调（仅用于监听，不要在此清除选区）
  final void Function(TextSelection selection, SelectionChangedCause? cause)?
      onSelectionChanged;

  /// 是否启用交互式选择（默认 true）
  final bool enableInteractiveSelection;

  const ChatMessageSelectableText({
    super.key,
    required this.message,
    this.style,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.maxLines,
    this.onSelectionChanged,
    this.enableInteractiveSelection = true,
  });

  @override
  State<ChatMessageSelectableText> createState() =>
      _ChatMessageSelectableTextState();
}

class _ChatMessageSelectableTextState
    extends State<ChatMessageSelectableText> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 使用 SelectableText 实现文本选择功能
    // 关键修复：
    // 1. 使用 FocusNode 保持焦点，确保手柄显示
    // 2. textScaleFactor: 1.0 确保精确对齐
    // 3. 不手动清除选区，让 Flutter 默认行为处理
    return SelectableText(
      widget.message,
      style: widget.style,
      textAlign: widget.textAlign,
      textDirection: widget.textDirection,
      maxLines: widget.maxLines,
      textScaleFactor: 1.0, // 【修复问题2】固定缩放因子，确保精确对齐
      onSelectionChanged: widget.onSelectionChanged,
      focusNode: _focusNode, // 【修复问题3】使用 FocusNode 保持焦点
      showCursor: false, // 隐藏光标（消息是只读的），但不影响手柄显示
      enableInteractiveSelection: widget.enableInteractiveSelection,
      selectionControls: ChatMessageSelectionControls(),
      // 【修复问题3】确保选中后不立即消失
      // 不设置 contextMenuBuilder，使用系统默认行为
    );
  }
}

/// 支持富文本的聊天消息可选中文本组件
/// 
/// 使用 `SelectableText.rich` 支持 Markdown、加粗、多级标题等样式
/// 
/// ⚠️ **重要限制**：
/// - **禁止使用 `WidgetSpan`**（会破坏文本连续性，导致双击失效和选区错位）
/// - 表情应使用 Unicode 字符（如 😀、👍），而非 `WidgetSpan` 包裹的图片
/// - 富文本应尽量简化为单一 `TextSpan` 树，避免嵌套交互元素
/// 
/// ✅ **推荐做法**：
/// - 使用 Unicode 表情字符：`TextSpan(text: 'Hello 😀 world')`
/// - 使用样式变化：`TextSpan(style: TextStyle(fontWeight: FontWeight.bold))`
/// - 使用颜色变化：`TextSpan(style: TextStyle(color: Colors.red))`
/// 
/// ❌ **禁止做法**：
/// - 不要使用 `WidgetSpan(child: Image.asset(...))` 嵌入图片
/// - 不要使用 `WidgetSpan(child: Icon(...))` 嵌入图标
/// - 不要嵌套可交互的 Widget（如按钮、链接等）
/// 
/// 示例用法：
/// ```dart
/// ChatMessageSelectableTextRich(
///   textSpan: TextSpan(
///     text: 'Hello ',
///     style: TextStyle(fontSize: 16),
///     children: [
///       TextSpan(
///         text: 'world',
///         style: TextStyle(fontWeight: FontWeight.bold),
///       ),
///       TextSpan(text: ' 😀'), // Unicode 表情
///     ],
///   ),
/// )
/// ```
class ChatMessageSelectableTextRich extends StatefulWidget {
  /// 要显示的富文本
  /// 
  /// ⚠️ 必须确保 `textSpan` 及其所有子节点都是 `TextSpan`，不能包含 `WidgetSpan`
  final TextSpan textSpan;

  /// 文本对齐方式
  final TextAlign textAlign;

  /// 文本方向
  final TextDirection? textDirection;

  /// 最大行数，null 表示不限制
  final int? maxLines;

  /// 选择改变时的回调（仅用于监听，不要在此清除选区）
  final void Function(TextSelection selection, SelectionChangedCause? cause)?
      onSelectionChanged;

  /// 是否启用交互式选择（默认 true）
  final bool enableInteractiveSelection;

  const ChatMessageSelectableTextRich({
    super.key,
    required this.textSpan,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.maxLines,
    this.onSelectionChanged,
    this.enableInteractiveSelection = true,
  });

  @override
  State<ChatMessageSelectableTextRich> createState() =>
      _ChatMessageSelectableTextRichState();
}

class _ChatMessageSelectableTextRichState
    extends State<ChatMessageSelectableTextRich> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 【修复问题1】验证 textSpan 不包含 WidgetSpan
    _validateTextSpan(widget.textSpan);
  }

  /// 验证 TextSpan 不包含 WidgetSpan
  void _validateTextSpan(InlineSpan span) {
    if (span is WidgetSpan) {
      throw ArgumentError(
        'ChatMessageSelectableTextRich 不支持 WidgetSpan。'
        '请使用 Unicode 表情字符（如 😀）替代图片，或使用 TextSpan + 样式实现富文本。',
      );
    }
    if (span is TextSpan && span.children != null) {
      for (final child in span.children!) {
        _validateTextSpan(child);
      }
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 使用 SelectableText.rich 实现富文本选择功能
    // 关键修复：
    // 1. 使用 FocusNode 保持焦点，确保手柄显示
    // 2. textScaleFactor: 1.0 确保精确对齐
    // 3. 不手动清除选区，让 Flutter 默认行为处理
    // 4. 确保 textSpan 不包含 WidgetSpan（已在 initState 验证）
    return SelectableText.rich(
      widget.textSpan,
      textAlign: widget.textAlign,
      textDirection: widget.textDirection,
      maxLines: widget.maxLines,
      textScaleFactor: 1.0, // 【修复问题2】固定缩放因子，确保精确对齐
      onSelectionChanged: widget.onSelectionChanged,
      focusNode: _focusNode, // 【修复问题3】使用 FocusNode 保持焦点
      showCursor: false, // 隐藏光标（消息是只读的），但不影响手柄显示
      enableInteractiveSelection: widget.enableInteractiveSelection,
      selectionControls: ChatMessageSelectionControls(),
      // 【修复问题3】确保选中后不立即消失
      // 不设置 contextMenuBuilder，使用系统默认行为
    );
  }
}

/// 自定义选择控制器，保持 Android 原生样式
/// 
/// 继承自 MaterialTextSelectionControls，提供标准的文本选择交互
/// 包括双击选中单词、长按选择、拖动手柄等功能
/// 
/// 【修复问题3】确保工具栏操作后不自动清除选区
class ChatMessageSelectionControls extends MaterialTextSelectionControls {
  ChatMessageSelectionControls();

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
    // 使用系统默认的工具栏（复制、全选等操作）
    // MaterialTextSelectionControls 已经实现了标准的上下文菜单
    // 工具栏操作后，Flutter 默认会保持选中状态，直到用户点击外部
    return super.buildToolbar(
      context,
      globalEditableRegion,
      textLineHeight,
      selectionMidpoint,
      endpoints,
      delegate,
      clipboardStatus,
      lastSecondaryTapDownPosition,
    );
  }

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) {
    // 使用系统默认的手柄样式（蓝色小水滴）
    // 手柄颜色由 ThemeData.textSelectionTheme.selectionHandleColor 控制
    // 【修复问题3】确保手柄正常显示
    return super.buildHandle(context, type, textLineHeight, onTap);
  }

  @override
  Size getHandleSize(double textLineHeight) {
    // 使用系统默认的手柄大小
    return super.getHandleSize(textLineHeight);
  }
}

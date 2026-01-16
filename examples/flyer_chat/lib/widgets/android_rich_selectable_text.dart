import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Android 风格富文本可选中组件（仅 Flutter 实现，Android 平台样式）
///
/// - 支持 `TextSpan` 富文本长按选择 / 拖动手柄调整范围 / 点击空白取消
/// - 自定义 Android 风格暗色菜单：复制 / 全选 / 分享
/// - 监听并打印选中文本 + 选择范围（start/end）
///
/// 约束：
/// - 仅适配 Android（其他平台退化为默认 `SelectableText.rich`）
/// - 不支持 `WidgetSpan`（会破坏连续选择）
class AndroidRichSelectableText extends StatefulWidget {
  /// 富文本内容（必须是纯 TextSpan 树，禁止 WidgetSpan）
  final TextSpan textSpan;

  /// 文本对齐
  final TextAlign textAlign;

  /// 最大行数（null 不限制）
  final int? maxLines;

  const AndroidRichSelectableText({
    super.key,
    required this.textSpan,
    this.textAlign = TextAlign.start,
    this.maxLines,
  });

  @override
  State<AndroidRichSelectableText> createState() =>
      _AndroidRichSelectableTextState();
}

class _AndroidRichSelectableTextState extends State<AndroidRichSelectableText> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _validateNoWidgetSpan(widget.textSpan);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _validateNoWidgetSpan(InlineSpan span) {
    if (span is WidgetSpan) {
      throw ArgumentError(
        'AndroidRichSelectableText 不支持 WidgetSpan。请使用 TextSpan + 样式，'
        '表情请用 Unicode 字符。',
      );
    }
    if (span is TextSpan) {
      final children = span.children;
      if (children != null) {
        for (final child in children) {
          _validateNoWidgetSpan(child);
        }
      }
    }
  }

  static const _AndroidSelectionColors _colors = _AndroidSelectionColors();

  @override
  Widget build(BuildContext context) {
    // 空文本：不启用交互
    final plain = _PlainText.flatten(widget.textSpan);
    if (plain.isEmpty) {
      return Text.rich(
        widget.textSpan,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
      );
    }

    // 非 Android：退化为默认行为
    if (!Platform.isAndroid) {
      return SelectableText.rich(
        widget.textSpan,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        showCursor: false,
      );
    }

    // Android：注入 selection theme + 自定义菜单/手柄色
    final themed = Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: const TextSelectionThemeData(
          selectionColor: _AndroidSelectionColors.selectionColor,
          selectionHandleColor: _AndroidSelectionColors.handleColor,
        ),
      ),
      child: SelectableText.rich(
        widget.textSpan,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        textScaleFactor: 1.0,
        focusNode: _focusNode,
        showCursor: false,
        selectionControls: AndroidSelectionControls(
          menuBackground: _colors.menuBackground,
          menuTextColor: _colors.menuTextColor,
          menuPressedOverlay: _colors.menuPressedOverlay,
          onShare: (selectedText) {
            // 按需求：模拟分享逻辑（打印）
            debugPrint('Share: "$selectedText"');
          },
        ),
        onSelectionChanged: (selection, cause) {
          if (!selection.isValid || selection.isCollapsed) return;
          final selectedText = _PlainText.safeSubstring(
            plain,
            selection.start,
            selection.end,
          );
          debugPrint(
            'Selected: "$selectedText" (${selection.start}, ${selection.end})',
          );
        },
      ),
    );

    // 点击空白处取消选择（通过失焦触发系统清除）
    return TapRegion(
      onTapOutside: (_) => _focusNode.unfocus(),
      child: themed,
    );
  }
}

/// Android 风格选择控制（菜单 + 手柄）
class AndroidSelectionControls extends MaterialTextSelectionControls {
  final Color menuBackground;
  final Color menuTextColor;
  final Color menuPressedOverlay;
  final ValueChanged<String> onShare;

  AndroidSelectionControls({
    required this.menuBackground,
    required this.menuTextColor,
    required this.menuPressedOverlay,
    required this.onShare,
  });

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
    final selection = delegate.textEditingValue.selection;
    final text = delegate.textEditingValue.text;
    final hasSelection = selection.isValid && !selection.isCollapsed;

    if (!hasSelection) {
      return const SizedBox.shrink();
    }

    final selectedText = text.substring(selection.start, selection.end);

    final anchors = TextSelectionToolbarAnchors.fromSelection(
      renderBox: context.findRenderObject()! as RenderBox,
      selectionEndpoints: endpoints,
      startGlyphHeight: textLineHeight,
      endGlyphHeight: textLineHeight,
    );

    return TextSelectionToolbar(
      anchorAbove: anchors.primaryAnchor,
      anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
      toolbarBuilder: (context, child) {
        return Material(
          color: menuBackground,
          elevation: 6,
          borderRadius: BorderRadius.circular(10),
          child: child,
        );
      },
      children: [
        _ToolbarButton(
          label: '复制',
          textColor: menuTextColor,
          pressedOverlay: menuPressedOverlay,
          onPressed: () {
            delegate.copySelection(SelectionChangedCause.toolbar);
            // 保持选区（不主动清除）
          },
        ),
        _ToolbarButton(
          label: '全选',
          textColor: menuTextColor,
          pressedOverlay: menuPressedOverlay,
          onPressed: () {
            delegate.selectAll(SelectionChangedCause.toolbar);
          },
        ),
        _ToolbarButton(
          label: '分享',
          textColor: menuTextColor,
          pressedOverlay: menuPressedOverlay,
          onPressed: () {
            // “分享”按需求：打印
            onShare(selectedText);
          },
        ),
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color pressedOverlay;
  final VoidCallback onPressed;

  const _ToolbarButton({
    required this.label,
    required this.textColor,
    required this.pressedOverlay,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextSelectionToolbarTextButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onPressed: onPressed,
      child: DefaultTextStyle(
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        child: Text(label),
      ),
    );
  }
}

class _AndroidSelectionColors {
  const _AndroidSelectionColors();

  // 选中高亮背景：#7F7F7F，透明度 0.2
  static const Color selectionColor = Color(0x337F7F7F);

  // 手柄颜色：#007AFF
  static const Color handleColor = Color(0xFF007AFF);

  // 菜单背景：#333333
  final Color menuBackground = const Color(0xFF333333);

  // 菜单文字：白色
  final Color menuTextColor = Colors.white;

  // 点击态高亮反馈（半透明白）
  final Color menuPressedOverlay = const Color(0x22FFFFFF);
}

class _PlainText {
  static String flatten(InlineSpan span) {
    final buffer = StringBuffer();
    _walk(span, buffer);
    return buffer.toString();
  }

  static void _walk(InlineSpan span, StringBuffer out) {
    if (span is TextSpan) {
      out.write(span.text ?? '');
      final children = span.children;
      if (children != null) {
        for (final c in children) {
          _walk(c, out);
        }
      }
    }
  }

  static String safeSubstring(String s, int start, int end) {
    final a = start.clamp(0, s.length);
    final b = end.clamp(0, s.length);
    if (b <= a) return '';
    return s.substring(a, b);
  }
}



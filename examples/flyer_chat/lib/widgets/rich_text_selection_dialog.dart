import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 选择模式对话框：点击“选择”后打开
///
/// 目标：
/// - 一进入就自动选中长按位置附近的“一个词/一段”
/// - 显示选择手柄与 Android 风格菜单（复制/全选/翻译）
class RichTextSelectionDialog extends StatefulWidget {
  final String plainText;
  final Offset longPressGlobalPosition;

  const RichTextSelectionDialog({
    super.key,
    required this.plainText,
    required this.longPressGlobalPosition,
  });

  @override
  State<RichTextSelectionDialog> createState() => _RichTextSelectionDialogState();
}

class _RichTextSelectionDialogState extends State<RichTextSelectionDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _editableKey = GlobalKey<EditableTextState>();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.plainText;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      _selectWordAtPress();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _selectWordAtPress() {
    final editableState = _editableKey.currentState;
    final render = editableState?.renderEditable;
    if (render == null) return;

    final box = render as RenderBox;
    // 将“长按点的全局坐标”映射到当前 EditableText 的本地坐标。
    // 由于本组件会在长按点附近定位显示（见 build），坐标能较准确地落在同一屏幕位置。
    final local = box.globalToLocal(widget.longPressGlobalPosition);
    final clampedLocal = Offset(
      local.dx.clamp(0.0, box.size.width),
      local.dy.clamp(0.0, box.size.height),
    );
    final pos = render.getPositionForPoint(clampedLocal);

    final text = _controller.text;
    if (text.isEmpty) return;

    // 用 TextPainter 计算 word boundary（更接近系统的“选中一个词”）
    final painter = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(fontSize: 14)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: render.size.width);

    final word = painter.getWordBoundary(pos);
    final start = word.start.clamp(0, text.length);
    final end = word.end.clamp(0, text.length);
    _controller.selection = TextSelection(baseOffset: start, extentOffset: end);

    debugPrint('Selected: "${text.substring(start, end)}" ($start,$end)');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.plainText.isEmpty) {
      return const AlertDialog(content: Text('空文本'));
    }

    final media = MediaQuery.of(context);
    const panelWidth = 320.0;
    const panelMaxHeight = 520.0;
    const margin = 8.0;

    // 面板尽量显示在长按点附近，避免超出屏幕
    final desiredLeft = widget.longPressGlobalPosition.dx - panelWidth / 2;
    final left = desiredLeft.clamp(margin, media.size.width - panelWidth - margin);
    final desiredTop = widget.longPressGlobalPosition.dy + 12;
    final top = desiredTop.clamp(margin, media.size.height - panelMaxHeight - margin);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // 点击空白关闭整层
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => Navigator.of(context).pop(),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: left.toDouble(),
            top: top.toDouble(),
            width: panelWidth,
            child: Material(
              color: Colors.white,
              elevation: 10,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: panelMaxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      textSelectionTheme: const TextSelectionThemeData(
                        selectionColor: Color(0x337F7F7F), // #7F7F7F @ 0.2
                        selectionHandleColor: Color(0xFF007AFF), // #007AFF
                      ),
                    ),
                    child: TapRegion(
                      onTapOutside: (_) => _focusNode.unfocus(),
                      child: EditableText(
                        key: _editableKey,
                        controller: _controller,
                        focusNode: _focusNode,
                        readOnly: true,
                        showCursor: false,
                        maxLines: null,
                        style: const TextStyle(fontSize: 14, color: Colors.black),
                        cursorColor: const Color(0xFF007AFF),
                        backgroundCursorColor: Colors.grey,
                        selectionControls: _AndroidLikeControls(
                          onTranslate: (selected) {
                            debugPrint('Translate: "$selected"');
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AndroidLikeControls extends MaterialTextSelectionControls {
  final ValueChanged<String> onTranslate;

  _AndroidLikeControls({required this.onTranslate});

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
    if (!selection.isValid || selection.isCollapsed) {
      return const SizedBox.shrink();
    }

    final text = delegate.textEditingValue.text;
    final selected = text.substring(selection.start, selection.end);

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
          color: const Color(0xFF333333),
          elevation: 6,
          borderRadius: BorderRadius.circular(10),
          child: child,
        );
      },
      children: [
        _btn('复制', () => delegate.copySelection(SelectionChangedCause.toolbar)),
        _btn('全选', () => delegate.selectAll(SelectionChangedCause.toolbar)),
        _btn('翻译', () => onTranslate(selected)),
      ],
    );
  }

  Widget _btn(String label, VoidCallback onPressed) {
    return TextSelectionToolbarTextButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}



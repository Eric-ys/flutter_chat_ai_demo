import 'package:flutter/material.dart';

/// Android 风格消息长按弹窗（轻量实现）
///
/// - 深色背景、白色文字、点击态高亮
/// - 提供：选择 / 复制 / 翻译
class AndroidMessageActionPopup extends StatelessWidget {
  final VoidCallback onSelect;
  final VoidCallback onCopy;
  final VoidCallback onTranslate;
  final VoidCallback? onRequestClose;

  const AndroidMessageActionPopup({
    super.key,
    required this.onSelect,
    required this.onCopy,
    required this.onTranslate,
    this.onRequestClose,
  });

  static const Color _bg = Color(0xFF333333);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: IntrinsicWidth(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Item(
                label: '选择',
                onTap: () {
                  onRequestClose?.call();
                  onSelect();
                },
              ),
              const _VDivider(),
              _Item(
                label: '复制',
                onTap: () {
                  onRequestClose?.call();
                  onCopy();
                },
              ),
              const _VDivider(),
              _Item(
                label: '翻译',
                onTap: () {
                  onRequestClose?.call();
                  onTranslate();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VDivider extends StatelessWidget {
  const _VDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 1,
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(color: Color(0x22FFFFFF)),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _Item({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      overlayColor: const WidgetStatePropertyAll(Color(0x22FFFFFF)),
      onTap: () {
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}



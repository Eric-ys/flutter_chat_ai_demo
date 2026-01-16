import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';

import '../services/offline_translator.dart';

/// SelectionArea 的自定义 Android 风格工具条（深色）
///
/// 说明：该组件依赖 Flutter 的 `SelectionArea.contextMenuBuilder` 回调传入的 state。
/// 不同 Flutter 版本 state 的类型名可能不同，但主流版本为 `SelectableRegionState`。
class AndroidSelectionToolbar extends StatelessWidget {
  final dynamic state;

  const AndroidSelectionToolbar({super.key, required this.state});

  static const _bg = Color(0xFF333333);
  static const _fg = Colors.white;

  @override
  Widget build(BuildContext context) {
    // 尝试从 state 取 anchors（不同 Flutter 版本字段名略有差异）
    final anchors = state.contextMenuAnchors;

    return TextSelectionToolbar(
      anchorAbove: anchors.primaryAnchor,
      anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
      toolbarBuilder: (context, child) {
        return Material(
          color: _bg,
          elevation: 6,
          borderRadius: BorderRadius.circular(10),
          child: child,
        );
      },
      children: [
        _btn('复制', () async {
          // ✅ 使用 SelectableRegion 的 copySelection（最稳定）
          try {
            state.copySelection(SelectionChangedCause.toolbar);
          } catch (_) {
            final selected = await _getSelectedTextAsync();
            if (selected.isNotEmpty) {
              await Clipboard.setData(ClipboardData(text: selected));
            }
          }

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已复制')),
            );
          }
          _hide();
        }),
        _btn('全选', () {
          // 全选
          state.selectAll(SelectionChangedCause.toolbar);
        }),
        _btn('翻译', () async {
          // ⚠️ 重要：不要在 await 之后再用 context 查找 ScaffoldMessenger（此时 toolbar 可能已被移除导致 context deactivated）
          final messenger = ScaffoldMessenger.maybeOf(context);

          // ✅ 兼容性最强：先 copySelection，再从剪贴板读取选中文本
          String selected = '';
          try {
            state.copySelection(SelectionChangedCause.toolbar);
            // 给系统一点时间写入剪贴板（部分机型/版本需要）
            await Future<void>.delayed(const Duration(milliseconds: 10));
            final data = await Clipboard.getData('text/plain');
            selected = (data?.text ?? '').trim();
          } catch (e) {
            debugPrint('Translate: copySelection/clipboard failed: $e');
          }

          // fallback：直接从 SelectionArea 获取
          selected = selected.isNotEmpty ? selected : (await _getSelectedTextAsync());
          if (selected.isEmpty) {
            debugPrint('Translate: selected text empty');
            return;
          }

          await OfflineTranslator.instance.initialize();
          final translated = OfflineTranslator.instance.translateAuto(selected);
          debugPrint('Translate: "$selected" -> "${translated ?? "未收录"}"');

          messenger?.showSnackBar(
            SnackBar(content: Text(translated ?? '未收录')),
          );
          _hide();
        }),
      ],
    );
  }

  Widget _btn(String label, VoidCallback onPressed) {
    return TextSelectionToolbarTextButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(color: _fg, fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }

  Future<String> _getSelectedTextAsync() async {
    try {
      final result = state.getSelectedContent();
      final content = result is Future ? await result : result;
      final plainText = content?.plainText as String?;
      return (plainText ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  void _hide() {
    try {
      state.hideToolbar();
    } catch (_) {
      // ignore
    }
    try {
      ContextMenuController.removeAny();
    } catch (_) {
      // ignore
    }
  }
}



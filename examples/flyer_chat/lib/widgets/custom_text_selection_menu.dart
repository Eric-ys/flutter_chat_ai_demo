import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

/// 自定义文本选择菜单，样式与系统一致
/// 支持复制、全选、翻译等功能
class CustomTextSelectionMenu extends StatelessWidget {
  final dynamic state; // SelectableRegionState
  final void Function(String)? onTranslate;

  const CustomTextSelectionMenu({
    super.key,
    required this.state,
    this.onTranslate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // 获取选择区域的位置
    final anchors = state.contextMenuAnchors;

    return TextSelectionToolbar(
      anchorAbove: anchors.primaryAnchor,
      anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
      toolbarBuilder: (context, child) {
        // 使用 Material 3 的样式，与系统保持一致
        return Material(
          color: isDark 
              ? const Color(0xFF2C2C2E) // iOS 深色模式背景色
              : const Color(0xFFFFFFFF), // iOS 浅色模式背景色
          elevation: 8,
          borderRadius: BorderRadius.circular(10),
          shadowColor: Colors.black.withOpacity(0.2),
          child: child,
        );
      },
      children: [
        _buildMenuItem(
          context: context,
          icon: Icons.content_copy,
          label: '复制',
          onPressed: () => _handleCopy(context),
          isDark: isDark,
        ),
        _buildMenuItem(
          context: context,
          icon: Icons.select_all,
          label: '全选',
          onPressed: () => _handleSelectAll(),
          isDark: isDark,
        ),
        _buildMenuItem(
          context: context,
          icon: Icons.translate,
          label: '翻译',
          onPressed: () => _handleTranslate(context),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isDark,
  }) {
    return TextSelectionToolbarTextButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isDark ? Colors.white : Colors.black87,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  /// 处理复制操作
  Future<void> _handleCopy(BuildContext context) async {
    try {
      // 使用 SelectableRegion 的 copySelection 方法
      state.copySelection(SelectionChangedCause.toolbar);
      
      // 显示复制成功提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('已复制'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 100),
          ),
        );
      }
    } catch (e) {
      // 如果 copySelection 失败，尝试从剪贴板获取
      debugPrint('复制失败: $e');
      final selectedText = await _getSelectedText();
      if (selectedText.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: selectedText));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已复制'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    }
    
    _hideToolbar();
  }

  /// 处理全选操作
  void _handleSelectAll() {
    try {
      state.selectAll(SelectionChangedCause.toolbar);
    } catch (e) {
      debugPrint('全选失败: $e');
    }
  }

  /// 处理翻译操作
  Future<void> _handleTranslate(BuildContext context) async {
    debugPrint('🌐 CustomTextSelectionMenu._handleTranslate 被调用');
    
    // 获取选中的文本
    String selectedText = '';
    
    try {
      // 先尝试直接从 state 获取（更可靠）
      selectedText = await _getSelectedText();
      debugPrint('📝 从 state 获取文本: "$selectedText"');
      
      // 如果失败，尝试从剪贴板获取
      if (selectedText.isEmpty) {
        debugPrint('📋 尝试从剪贴板获取文本...');
        state.copySelection(SelectionChangedCause.toolbar);
        // 等待系统写入剪贴板
        await Future.delayed(const Duration(milliseconds: 100));
        final clipboardData = await Clipboard.getData('text/plain');
        selectedText = (clipboardData?.text ?? '').trim();
        debugPrint('📋 从剪贴板获取文本: "$selectedText"');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 获取选中文本失败: $e');
      debugPrint('堆栈跟踪: $stackTrace');
    }
    
    if (selectedText.isEmpty) {
      debugPrint('⚠️ 未选中文本');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('未选中文本'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      _hideToolbar();
      return;
    }
    
    debugPrint('✅ 获取到选中文本: "$selectedText"');
    debugPrint('📞 调用翻译回调: onTranslate=${onTranslate != null}');
    
    // 调用翻译回调
    if (onTranslate != null) {
      try {
        onTranslate!(selectedText);
        debugPrint('✅ 翻译回调已调用');
      } catch (e, stackTrace) {
        debugPrint('❌ 翻译回调执行失败: $e');
        debugPrint('堆栈跟踪: $stackTrace');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('翻译失败: $e'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      debugPrint('⚠️ 未提供翻译回调');
      // 如果没有提供翻译回调，显示一个提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('翻译: $selectedText'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
    
    _hideToolbar();
  }

  /// 获取选中的文本
  Future<String> _getSelectedText() async {
    try {
      // 尝试多种方法获取选中文本
      // 方法1: 使用 copySelection 然后从剪贴板读取
      try {
        state.copySelection(SelectionChangedCause.toolbar);
        await Future.delayed(const Duration(milliseconds: 100));
        final clipboardData = await Clipboard.getData('text/plain');
        final text = (clipboardData?.text ?? '').trim();
        if (text.isNotEmpty) {
          return text;
        }
      } catch (e) {
        debugPrint('方法1失败: $e');
      }
      
      // 方法2: 尝试直接访问 selectedContent 属性
      try {
        final selectedContent = state.selectedContent;
        if (selectedContent != null) {
          final plainText = selectedContent.plainText as String?;
          if (plainText != null && plainText.isNotEmpty) {
            return plainText.trim();
          }
        }
      } catch (e) {
        debugPrint('方法2失败: $e');
      }
      
      // 方法3: 尝试调用 getSelectedContent()（如果存在）
      try {
        final result = state.getSelectedContent();
        final content = result is Future ? await result : result;
        final plainText = content?.plainText as String?;
        if (plainText != null && plainText.isNotEmpty) {
          return plainText.trim();
        }
      } catch (e) {
        debugPrint('方法3失败: $e');
      }
      
      return '';
    } catch (e) {
      debugPrint('获取选中文本失败: $e');
      return '';
    }
  }

  /// 隐藏工具栏
  void _hideToolbar() {
    try {
      state.hideToolbar();
    } catch (e) {
      debugPrint('隐藏工具栏失败: $e');
    }
    try {
      ContextMenuController.removeAny();
    } catch (e) {
      debugPrint('移除上下文菜单失败: $e');
    }
  }
}


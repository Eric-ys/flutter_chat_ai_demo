import 'package:flutter/material.dart';
import 'chat_message_selectable_text.dart';

/// 示例：如何在聊天应用中使用 ChatMessageSelectableText
/// 
/// 这个文件展示了如何使用 ChatMessageSelectableText 组件
/// 来实现与 Android 原生系统一致的文本选择体验。
class ChatMessageSelectableTextExample extends StatelessWidget {
  const ChatMessageSelectableTextExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文本选择示例'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 示例 1: 基本用法
          _buildMessageBubble(
            context,
            '基本用法',
            const ChatMessageSelectableText(
              message: 'Hello, double-tap to select this word!',
              style: TextStyle(fontSize: 16),
            ),
          ),

          const SizedBox(height: 16),

          // 示例 2: 多行文本
          _buildMessageBubble(
            context,
            '多行文本',
            const ChatMessageSelectableText(
              message:
                  'This is a long message that spans multiple lines. '
                  'You can double-tap any word to select it, or long-press '
                  'to start a custom selection. Drag the handles to adjust '
                  'the selection range.',
              style: TextStyle(fontSize: 16),
              maxLines: null,
            ),
          ),

          const SizedBox(height: 16),

          // 示例 3: 富文本（加粗、斜体等）
          _buildMessageBubble(
            context,
            '富文本（支持双击选中）',
            ChatMessageSelectableTextRich(
              textSpan: const TextSpan(
                text: 'Hello ',
                style: TextStyle(fontSize: 16),
                children: [
                  TextSpan(
                    text: 'world',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  TextSpan(text: '! You can select '),
                  TextSpan(
                    text: 'bold text',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(text: ' or '),
                  TextSpan(
                    text: 'italic text',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  TextSpan(text: ' too.'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 示例 3.5: Unicode 表情（推荐方式）
          _buildMessageBubble(
            context,
            'Unicode 表情（推荐）',
            const ChatMessageSelectableText(
              message: 'Hello 😀 world 👍 You can select emoji too! 🎉',
              style: TextStyle(fontSize: 16),
            ),
          ),

          const SizedBox(height: 16),

          // 示例 4: 中英文混合
          _buildMessageBubble(
            context,
            '中英文混合',
            const ChatMessageSelectableText(
              message: 'Hello 世界！You can select 中文 or English words.',
              style: TextStyle(fontSize: 16),
            ),
          ),

          const SizedBox(height: 16),

          // 示例 5: 自定义样式
          _buildMessageBubble(
            context,
            '自定义样式',
            ChatMessageSelectableText(
              message: 'This message has custom styling.',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 示例 6: 监听选择变化
          _buildMessageBubble(
            context,
            '监听选择变化',
            ChatMessageSelectableText(
              message: 'Select text to see the callback.',
              style: const TextStyle(fontSize: 16),
              onSelectionChanged: (selection, cause) {
                if (selection.isValid && !selection.isCollapsed) {
                  debugPrint(
                    'Selected: ${selection.start} - ${selection.end}',
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    String title,
    Widget content,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: content,
        ),
      ],
    );
  }
}


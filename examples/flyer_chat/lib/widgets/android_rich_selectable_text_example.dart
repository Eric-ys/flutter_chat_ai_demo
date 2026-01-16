import 'package:flutter/material.dart';

import 'android_rich_selectable_text.dart';

/// 示例页：Android 风格富文本选择
class AndroidRichSelectableTextExample extends StatelessWidget {
  const AndroidRichSelectableTextExample({super.key});

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(fontSize: 14, color: Colors.black);
    const title = TextStyle(
      fontSize: 16,
      color: Colors.blue,
      fontWeight: FontWeight.bold,
    );
    const note = TextStyle(
      fontSize: 14,
      color: Colors.red,
      fontStyle: FontStyle.italic,
    );

    final span = TextSpan(
      style: base,
      children: const [
        TextSpan(text: '标题：', style: title),
        TextSpan(text: '这是一个可选中的富文本组件。\n\n'),
        TextSpan(text: '正文：'),
        TextSpan(text: '支持 '),
        TextSpan(
          text: '粗体',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        TextSpan(text: ' / '),
        TextSpan(
          text: '斜体',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
        TextSpan(text: ' / '),
        TextSpan(
          text: '不同颜色',
          style: TextStyle(color: Colors.green),
        ),
        TextSpan(text: ' / '),
        TextSpan(
          text: '不同字号',
          style: TextStyle(fontSize: 18),
        ),
        TextSpan(text: '，并且可跨样式选择。\n\n'),
        TextSpan(text: '备注：', style: note),
        TextSpan(text: '长按任意位置开始选择，拖动手柄调整范围，点击空白处取消。', style: note),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Android 富文本选择示例')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: AndroidRichSelectableText(textSpan: span),
          ),
        ),
      ),
    );
  }
}



# ChatMessageSelectableText 使用说明

## 概述

`ChatMessageSelectableText` 组件提供与 Android 原生系统一致的文本选择体验，包括：

- ✅ 双击单词自动选中整个单词
- ✅ 长按或拖动可自定义选择范围
- ✅ 显示两个可拖动的光标手柄（蓝色小水滴样式）
- ✅ 支持复制、全选等标准操作
- ✅ 选中状态在菜单操作后保持，直到用户点击空白处

## 已修复的问题

### ✅ 问题 1：双击富文本消息无反应
**修复方案**：
- 确保 `enableInteractiveSelection: true`（默认值）
- 使用 `FocusNode` 保持焦点，确保手势事件正确传递
- 验证 `TextSpan` 不包含 `WidgetSpan`（会在初始化时检查并抛出错误）

### ✅ 问题 2：选中背景与文字区域错位
**修复方案**：
- 固定 `textScaleFactor: 1.0`，确保文本渲染一致性
- 禁止使用 `WidgetSpan`（会破坏文本连续性）
- 使用 Unicode 表情字符替代图片

### ✅ 问题 3：选中后无光标手柄，且弹窗关闭即消失
**修复方案**：
- 使用 `FocusNode` 保持焦点，确保手柄显示
- 不手动清除选区（不在 `onSelectionChanged` 中调用 `clearSelection()`）
- 依赖 Flutter 默认行为：选中后自动显示手柄，菜单操作后保持高亮

## 基本用法

### 普通文本

```dart
ChatMessageSelectableText(
  message: 'Hello, double-tap to select this word!',
  style: TextStyle(fontSize: 16),
)
```

### 富文本（推荐）

```dart
ChatMessageSelectableTextRich(
  textSpan: TextSpan(
    text: 'Hello ',
    style: TextStyle(fontSize: 16),
    children: [
      TextSpan(
        text: 'world',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
      TextSpan(text: ' 😀'), // Unicode 表情
    ],
  ),
)
```

## 重要限制

### ❌ 禁止使用 WidgetSpan

**为什么不能使用 `WidgetSpan`？**

1. **破坏文本连续性**：`WidgetSpan` 会在文本流中插入非文本元素，导致文本选择计算错误
2. **双击失效**：`SelectableText.rich` 无法在包含 `WidgetSpan` 的文本上正确识别单词边界
3. **选区错位**：选中背景无法准确对齐到文字区域

**错误示例**：
```dart
// ❌ 不要这样做
ChatMessageSelectableTextRich(
  textSpan: TextSpan(
    children: [
      TextSpan(text: 'Hello '),
      WidgetSpan(child: Image.asset('emoji.png')), // ❌ 禁止
      TextSpan(text: ' world'),
    ],
  ),
)
```

### ✅ 推荐做法

#### 1. 使用 Unicode 表情字符

```dart
ChatMessageSelectableTextRich(
  textSpan: TextSpan(
    text: 'Hello 😀 world 👍', // ✅ 使用 Unicode 表情
    style: TextStyle(fontSize: 16),
  ),
)
```

#### 2. 使用样式变化

```dart
ChatMessageSelectableTextRich(
  textSpan: TextSpan(
    text: 'Hello ',
    style: TextStyle(fontSize: 16),
    children: [
      TextSpan(
        text: 'bold',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      TextSpan(
        text: ' italic',
        style: TextStyle(fontStyle: FontStyle.italic),
      ),
      TextSpan(
        text: ' colored',
        style: TextStyle(color: Colors.red),
      ),
    ],
  ),
)
```

#### 3. 使用 Markdown 渲染后的 TextSpan

如果你的消息使用 Markdown（如 `gpt_markdown`），可以这样处理：

```dart
// 假设你有一个函数将 Markdown 转换为 TextSpan
TextSpan markdownToTextSpan(String markdown) {
  // 使用 gpt_markdown 或其他库解析 Markdown
  // 返回只包含 TextSpan 的树结构（不包含 WidgetSpan）
  // ...
}

ChatMessageSelectableTextRich(
  textSpan: markdownToTextSpan('**bold** text with 😀 emoji'),
)
```

## 主题配置

在 `MaterialApp` 中配置文本选择主题，使手柄颜色与 App 品牌一致：

```dart
MaterialApp(
  theme: ThemeData(
    textSelectionTheme: const TextSelectionThemeData(
      selectionColor: Color(0x660000FF), // 蓝色选中背景，透明度 40%
      cursorColor: Color(0xFF0000FF), // 蓝色光标
      selectionHandleColor: Color(0xFF0000FF), // 蓝色选择手柄
    ),
  ),
  // ...
)
```

## 常见问题

### Q: 为什么双击没有反应？

A: 检查以下几点：
1. 确保 `enableInteractiveSelection: true`（默认值）
2. 确保 `textSpan` 不包含 `WidgetSpan`
3. 确保没有父级 `GestureDetector` 拦截双击事件
4. 确保 `SelectableText` 没有被 `AbsorbPointer` 或 `IgnorePointer` 包裹

### Q: 选中背景为什么错位？

A: 检查以下几点：
1. 确保 `textScaleFactor: 1.0`（已自动设置）
2. 确保不使用 `WidgetSpan`
3. 确保文本样式（字体大小、行高等）一致

### Q: 为什么没有显示选择手柄？

A: 检查以下几点：
1. 确保 `showCursor: false` 不影响手柄显示（已自动设置）
2. 确保 `FocusNode` 正确管理焦点（已自动创建）
3. 确保主题中配置了 `selectionHandleColor`
4. 确保没有父级手势拦截

### Q: 为什么选中后立即消失？

A: 检查以下几点：
1. **不要**在 `onSelectionChanged` 中调用 `clearSelection()`
2. **不要**在 `onTap` 中清除选区
3. 让 Flutter 默认行为处理：选中后保持，直到用户点击外部

### Q: 如何在聊天消息中嵌入表情？

A: 推荐使用 Unicode 表情字符：

```dart
// ✅ 推荐：使用 Unicode 表情
ChatMessageSelectableText(
  message: 'Hello 😀 world 👍',
  style: TextStyle(fontSize: 16),
)

// ❌ 不推荐：使用 WidgetSpan
ChatMessageSelectableTextRich(
  textSpan: TextSpan(
    children: [
      TextSpan(text: 'Hello '),
      WidgetSpan(child: Image.asset('emoji.png')), // ❌ 会导致选择失效
      TextSpan(text: ' world'),
    ],
  ),
)
```

## 性能优化

1. **避免频繁重建**：如果消息内容不变，使用 `const` 构造函数
2. **限制最大行数**：对于超长消息，设置 `maxLines` 限制
3. **避免深层嵌套**：`TextSpan` 树不要嵌套过深

## 示例代码

完整示例请参考 `chat_message_selectable_text_example.dart`。

